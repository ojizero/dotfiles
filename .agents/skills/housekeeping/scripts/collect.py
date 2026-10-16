#!/usr/bin/env python3
"""Bounded, read-only macOS inspection of current state. Writes nothing."""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import selectors
import signal
import socket
import stat
import subprocess
import time
from datetime import datetime, timezone

GIB = 1024 ** 3
MAX_OUTPUT = 32768
MAX_PS_OUTPUT = 1024 ** 2
MAX_ENTRIES = 10000


def canonical(value):
    p = Path(value)
    if not p.is_absolute() or p.resolve(strict=True) != p:
        raise ValueError("paths must exist, be absolute and contain no symlinks")
    return p


def contains(parent, child):
    return parent == child or parent in child.parents


def load_config(path):
    p = canonical(path)
    s = p.stat()
    if not stat.S_ISREG(s.st_mode) or s.st_uid != os.getuid() or s.st_mode & 0o022 or s.st_size > 16384:
        raise ValueError("config must be a small user-owned file without group/other writes")
    c = json.loads(p.read_text())
    if c['host'] != socket.gethostname():
        raise ValueError("host mismatch; set host to hostname output")
    canonical(c['disk_root'])
    if not Path(c['disk_root']).is_dir():
        raise ValueError("disk_root must be a directory on the measured volume")
    all_roots = []
    for key in ('roots', 'repositories'):
        values = c.setdefault(key, [])
        if not isinstance(values, list) or len(values) > 8:
            raise ValueError(key + " must contain at most eight directories")
        for value in values:
            root = canonical(value)
            if not root.is_dir() or root.stat().st_uid != os.getuid() or contains(root, Path.home()) or len(root.parts) < 4:
                raise ValueError("roots must be narrow user-owned directories")
            if any(contains(root, other) or contains(other, root) for other in all_roots):
                raise ValueError("inventory roots must not overlap")
            all_roots.append(root)
    for key, default, low, high in [('warning_percent', 15, 1, 90), ('urgent_gib', 25, 1, 1024)]:
        value = c.setdefault(key, default)
        if type(value) not in (int, float) or not low <= value <= high:
            raise ValueError(key + " is out of bounds")
    if 'docker_socket' in c:
        if not stat.S_ISSOCK(canonical(c['docker_socket']).stat().st_mode):
            raise ValueError("docker_socket must be an existing local Unix socket")
    return c


def command(args, deadline, limit=MAX_OUTPUT):
    """Bound both pipe output and wall time, including descendants."""
    remaining = min(2.0, deadline - time.monotonic())
    if remaining <= 0:
        return {'unknown': 'total runtime limit'}
    try:
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              start_new_session=True, env={**os.environ, 'LC_ALL': 'C',
                              'GIT_OPTIONAL_LOCKS': '0', 'GIT_TERMINAL_PROMPT': '0'}) as proc:
            output = bytearray()
            end = time.monotonic() + remaining
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                try:
                    while True:
                        wait = end - time.monotonic()
                        if wait <= 0 or not selector.select(wait):
                            return {'unknown': 'command timeout'}
                        chunk = os.read(proc.stdout.fileno(), 4096)
                        if not chunk:
                            code = proc.wait(timeout=max(0.001, end - time.monotonic()))
                            return {'text': output.decode('utf-8', 'replace')} if code == 0 else {'unknown': 'command failed'}
                        output.extend(chunk)
                        if len(output) > limit:
                            return {'unknown': 'command output limit'}
                finally:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
    except (OSError, subprocess.TimeoutExpired):
        return {'unknown': 'command unavailable or timed out'}


def allocated(root, deadline, seen):
    total, count = 0, 0
    try:
        device = root.stat().st_dev
        pending = [root]
        while pending:
            if time.monotonic() >= deadline or count >= MAX_ENTRIES:
                return {'unknown': 'scan limit', 'partial_allocated_bytes': total}
            p = pending.pop()
            s = p.lstat()
            count += 1
            if stat.S_ISLNK(s.st_mode) or s.st_dev != device or (s.st_dev, s.st_ino) in seen:
                continue
            seen.add((s.st_dev, s.st_ino))
            total += s.st_blocks * 512
            if stat.S_ISDIR(s.st_mode):
                with os.scandir(p) as entries:
                    for entry in entries:
                        if count + len(pending) >= MAX_ENTRIES or time.monotonic() >= deadline:
                            return {'unknown': 'scan limit', 'partial_allocated_bytes': total}
                        pending.append(Path(entry.path))
        return {'allocated_bytes': total, 'entries': count}
    except OSError:
        return {'unknown': 'scan inaccessible or changed', 'partial_allocated_bytes': total}


def number(result):
    try:
        return int(result['text'].strip())
    except (KeyError, ValueError):
        return None


def swap_bytes(result):
    match = re.search(r'used\s*=\s*([\d.]+)([MG])', result.get('text', ''))
    return int(float(match[1]) * (1024 ** (2 if match[2] == 'M' else 3))) if match else None


def status(free, capacity, pressure, config):
    if free < config['urgent_gib'] * GIB or pressure == 4:
        return 'urgent'
    if free / capacity * 100 < config['warning_percent'] or pressure == 2:
        return 'warning'
    return 'healthy'


def collect(c, review, deadline):
    v = os.statvfs(c['disk_root'])
    pressure = number(command(['/usr/sbin/sysctl', '-n', 'kern.memorystatus_vm_pressure_level'], deadline))
    swap = swap_bytes(command(['/usr/sbin/sysctl', '-n', 'vm.swapusage'], deadline))
    r = {'timestamp': datetime.now(timezone.utc).isoformat(), 'host': c['host'],
         'disk_root': c['disk_root'],
         'capacity_bytes': v.f_blocks * v.f_frsize, 'free_bytes': v.f_bavail * v.f_frsize,
         'pressure_level': pressure, 'swap_bytes': swap,
         'notices': [], 'mode': 'review' if review else 'quick'}
    r['status'] = status(r['free_bytes'], r['capacity_bytes'], pressure, c)
    if pressure not in (1, 2, 4):
        r['notices'].append('Current pressure unknown; used swap is not current pressure.')
    if swap is None:
        r['notices'].append('Swap usage unknown.')
    if r['status'] == 'healthy' and (pressure not in (1, 2, 4) or swap is None):
        r['status'] = 'unknown'
    if review:
        # Leave urgent reviews cheap enough to return evidence promptly.
        if r['status'] == 'urgent':
            deadline = min(deadline, time.monotonic() + 3)
        processes = command(['/bin/ps', '-axco', 'pid=,ppid=,lstart=,rss=,comm='], deadline, MAX_PS_OUTPUT)
        try:
            lines = [line.split(None, 8) for line in processes['text'].splitlines()]
            r['processes'] = sorted([{'pid': int(x[0]), 'ppid': int(x[1]),
                'start': ' '.join(x[2:7]), 'rss_kib': int(x[7]),
                'name': Path(x[8]).name[:80]} for x in lines],
                key=lambda x: x['rss_kib'], reverse=True)[:10]
        except (KeyError, ValueError, IndexError):
            r['processes'] = {'unknown': processes.get('unknown', 'unrecognized ps output')}
        r['roots'] = {}
        seen = set()
        for value in c['roots']:
            r['roots'][value] = {**allocated(Path(value), deadline, seen),
                                 'decision': 'needs-user-decision; inventory only'}
        r['worktrees'] = {value: command(['/usr/bin/git', '-c', 'core.fsmonitor=false', '-C', value,
                             'worktree', 'list', '--porcelain'], deadline) for value in c['repositories']}
        r['docker_logical'] = command(['docker', '--host', 'unix://' + c['docker_socket'],
                                     'system', 'df', '--format', '{{json .}}'], deadline) if 'docker_socket' in c else {'unknown': 'docker_socket unconfigured; daemon left alone'}
        if not c['roots'] or not c['repositories']:
            r['notices'].append('Storage roots or repository inventory unconfigured; no paths guessed.')
    return r


def run(config, review=False):
    if platform.system() != 'Darwin':
        return {'status': 'unsupported', 'notices': ['housekeeping supports macOS only']}
    try:
        c = load_config(config)
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        return {'status': 'unconfigured', 'notices': [str(exc)[:160],
                'Provide valid host and disk_root; see references/policy.md.']}
    try:
        return collect(c, review, time.monotonic() + 15)
    except OSError as exc:
        return {'status': 'unknown', 'notices': ['Collection failed: ' + (exc.strerror or 'OS error')]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--review', action='store_true')
    args = parser.parse_args()
    report = run(args.config, args.review)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'healthy' else 1


if __name__ == '__main__':
    raise SystemExit(main())
