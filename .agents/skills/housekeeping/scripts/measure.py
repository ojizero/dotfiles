"""Bounded, read-only measurements: disk, memory, sizes, and a command runner."""
import os
import re
import selectors
import signal
import subprocess
import time
from pathlib import Path

GIB = 1024 ** 3
PRESSURE = {1: 'normal', 2: 'warning', 4: 'critical'}


def run(args, timeout=10, cwd=None, limit=1024 ** 2):
    """Run a command with a wall-time and output bound. Kills its whole process group afterwards.

    Returns {'code': int, 'out': str} or {'code': None, 'out': partial, 'error': reason}.
    """
    env = {**os.environ, 'LC_ALL': 'C', 'GIT_OPTIONAL_LOCKS': '0', 'GIT_TERMINAL_PROMPT': '0',
           'HOMEBREW_NO_AUTO_UPDATE': '1', 'HOMEBREW_NO_INSTALL_CLEANUP': '1', 'NO_COLOR': '1'}
    try:
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                cwd=cwd, env=env, start_new_session=True)
    except OSError as exc:
        return {'code': None, 'out': '', 'error': f'{Path(args[0]).name} unavailable ({exc.strerror})'}
    out, end = bytearray(), time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as sel:
            sel.register(proc.stdout, selectors.EVENT_READ)
            while True:
                wait = end - time.monotonic()
                if wait <= 0 or not sel.select(wait):
                    return {'code': None, 'out': out.decode('utf-8', 'replace'), 'error': f'timed out after {timeout}s'}
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    break
                out.extend(chunk)
                if len(out) > limit:
                    del out[:len(out) - limit]
        code = proc.wait(timeout=max(0.1, end - time.monotonic()))
        return {'code': code, 'out': out.decode('utf-8', 'replace')}
    except subprocess.TimeoutExpired:
        return {'code': None, 'out': out.decode('utf-8', 'replace'), 'error': f'timed out after {timeout}s'}
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        proc.stdout.close()
        proc.wait()


def disk(root):
    v = os.statvfs(root)
    return {'capacity_bytes': v.f_blocks * v.f_frsize, 'free_bytes': v.f_bavail * v.f_frsize}


def free_bytes(root):
    return disk(root)['free_bytes']


def memory():
    level = run(['/usr/sbin/sysctl', '-n', 'kern.memorystatus_vm_pressure_level'])
    swap = run(['/usr/sbin/sysctl', '-n', 'vm.swapusage'])
    try:
        pressure = int(level['out'].strip())
    except ValueError:
        pressure = None
    m = re.search(r'used\s*=\s*([\d.]+)([MG])', swap['out'])
    procs = []
    ps = run(['/bin/ps', '-axco', 'pid=,rss=,comm='])
    for line in ps['out'].splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            procs.append({'pid': int(parts[0]), 'rss_bytes': int(parts[1]) * 1024, 'name': parts[2][:60]})
    procs.sort(key=lambda p: p['rss_bytes'], reverse=True)
    return {'pressure': PRESSURE.get(pressure, 'unknown'),
            'swap_bytes': int(float(m[1]) * 1024 ** (2 if m[2] == 'M' else 3)) if m else None,
            'top_processes': procs[:6]}


def status(free, capacity, warning_percent, urgent_gib):
    """Disk status only; memory pressure is reported separately because cleanup cannot fix it."""
    if free < urgent_gib * GIB:
        return 'urgent'
    if free / capacity * 100 < warning_percent:
        return 'warning'
    return 'healthy'


def du(path, timeout=20):
    """Allocated bytes under path (one filesystem), or None when unknown within the time bound."""
    r = run(['/usr/bin/du', '-skx', str(path)], timeout=timeout)
    try:
        return int(r['out'].split()[0]) * 1024 if r['code'] == 0 else None
    except (IndexError, ValueError):
        return None


def process_cwds():
    """Current working directories of all of this user's processes, or None when unknown."""
    r = run(['/usr/sbin/lsof', '-w', '-a', '-u', str(os.getuid()), '-d', 'cwd', '-Fn'], timeout=20, limit=8 * 1024 ** 2)
    if r['code'] not in (0, 1):
        return None
    return {line[1:] for line in r['out'].splitlines() if line.startswith('n/')}


def busy(pattern):
    """True when a process command line matches pattern (an extended regex)."""
    return run(['/usr/bin/pgrep', '-f', pattern])['code'] == 0


def newest_mtime(path):
    """Newest mtime of path and its direct children; directory mtimes miss deep writes but catch rebuilds."""
    times = [path.lstat().st_mtime]
    try:
        with os.scandir(path) as entries:
            times += [e.stat(follow_symlinks=False).st_mtime for e in entries]
    except OSError:
        pass
    return max(times)
