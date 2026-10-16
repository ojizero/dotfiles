"""Cleanup actions. Each uses the owning tool's own cleanup command and returns result dicts.

Result: {'category', 'label', 'outcome': done|skipped|kept|failed|planned, 'bytes', 'reason'}.
"""
import json
import re
import shutil
import time
from pathlib import Path

from measure import busy, du, free_bytes, newest_mtime, run

DAY = 86400
# Whole-run budget, so a run ends inside a 10-minute shell tool timeout. housekeeping.py sets DEADLINE.
BUDGET = 540
DEADLINE = float('inf')
# (id, category, label, command, busy pattern, timeout). Routine runs every time; deep only when disk space is low.
ROUTINE = [
    ('brew', 'caches', 'Homebrew old versions and downloads', ['brew', 'cleanup', '--prune=all'], r'Homebrew/brew\.rb', 900),
    ('uv', 'caches', 'uv unused cache entries', ['uv', 'cache', 'prune'], r'(^|/)uv (pip|sync|add|lock|tool)', 600),
    ('pnpm', 'caches', 'pnpm unreferenced store packages', ['pnpm', 'store', 'prune'], r'pnpm (install|i|add)( |$)', 600),
    ('simulators', 'xcode', 'Unavailable iOS simulators', ['xcrun', 'simctl', 'delete', 'unavailable'], None, 300),
]
DEEP = [
    ('uv-all', 'caches', 'uv entire cache', ['uv', 'cache', 'clean'], r'(^|/)uv (pip|sync|add|lock|tool)', 900),
    ('bun', 'caches', 'Bun package cache', ['bun', 'pm', 'cache', 'rm'], r'bun (install|i|add)( |$)', 600),
    ('npm', 'caches', 'npm package cache', ['npm', 'cache', 'clean', '--force'], r'npm (install|ci|i)( |$)', 600),
    ('nuget', 'caches', 'NuGet local caches', ['dotnet', 'nuget', 'locals', 'all', '--clear'], r'dotnet (restore|build|test)', 600),
    ('go', 'caches', 'Go build cache', ['go', 'clean', '-cache'], r'go (build|test|run)( |$)', 600),
]
VERSION = {'xcrun': ['xcrun', '--find', 'simctl'], 'go': ['go', 'version']}
XCODE_BUSY = r'xcodebuild|Xcode\.app/Contents/MacOS/Xcode'


def remaining(timeout):
    return max(5, min(timeout, DEADLINE - time.monotonic()))


def result(category, label, outcome, reason='', bytes=None):
    return {'category': category, 'label': label, 'outcome': outcome, 'reason': reason, 'bytes': bytes}


def available(tool):
    """True when the tool runs. A mise shim with no version set exists but fails, so run it."""
    if not shutil.which(tool):
        return False
    return run(VERSION.get(tool, [tool, '--version']), timeout=20)['code'] == 0


def freed(root, fn):
    """Run fn and return (its value, host free-space gained in bytes, never negative)."""
    before = free_bytes(root)
    value = fn()
    return value, max(0, free_bytes(root) - before)


def tool_action(spec, root, dry_run):
    _, category, label, argv, pattern, timeout = spec
    if not available(argv[0]):
        return result(category, label, 'skipped', f'{argv[0]} not installed')
    if pattern and busy(pattern):
        return result(category, label, 'skipped', f'{argv[0]} is installing something right now')
    if dry_run:
        return result(category, label, 'planned', ' '.join(argv))
    r, gained = freed(root, lambda: run(argv, timeout=remaining(timeout)))
    if r['code'] != 0:
        return result(category, label, 'failed', r.get('error') or last_line(r['out']))
    return result(category, label, 'done', ' '.join(argv), gained)


def last_line(text):
    lines = [x for x in text.strip().splitlines() if x.strip()]
    return (lines[-1] if lines else 'exited with an error')[:160]


UNITS = {'B': 1, 'kB': 1e3, 'KB': 1e3, 'MB': 1e6, 'GB': 1e9, 'TB': 1e12}


def reclaimed(text):
    """Sum Docker's 'Total reclaimed space: 1.2GB' and 'Total: 1.2GB' lines, in bytes."""
    total = 0
    for value, unit in re.findall(r'^Total(?: reclaimed space)?:\s*([\d.]+)\s*([kKMGT]?B)\s*$', text, re.M):
        total += int(float(value) * UNITS[unit])
    return total


def docker(root, deep, dry_run):
    """Prune unused images, build cache and networks older than 7 days. Never volumes or containers."""
    label = 'Docker images and build cache unused for 7+ days'
    if not shutil.which('docker'):
        return [result('docker', 'Docker', 'skipped', 'docker not installed')]
    if run(['docker', 'info', '--format', '{{.ServerVersion}}'], timeout=20)['code'] != 0:
        return [result('docker', 'Docker', 'skipped', 'Docker is not running; left stopped')]
    commands = [['docker', 'image', 'prune', '-af', '--filter', 'until=168h'],
                ['docker', 'builder', 'prune', '-af'] + ([] if deep else ['--filter', 'until=168h']),
                ['docker', 'network', 'prune', '-f', '--filter', 'until=168h']]
    if deep:
        label = 'Docker images unused for 7+ days and all build cache'
    out = []
    if dry_run:
        out.append(result('docker', label, 'planned', '; '.join(' '.join(c) for c in commands)))
    else:
        def prune():
            return [run(c, timeout=remaining(900)) for c in commands]
        runs, gained = freed(root, prune)
        failed = [r for r in runs if r['code'] != 0]
        reported = sum(reclaimed(r['out']) for r in runs)
        if failed:
            out.append(result('docker', label, 'failed', failed[0].get('error') or last_line(failed[0]['out']),
                              max(gained, reported)))
        else:
            note = f'Docker reported {reported / 1e9:.1f} GB; the host gets it back as the VM disk shrinks' \
                if reported > gained else ' '.join(commands[0])
            out.append(result('docker', label, 'done', note, max(gained, reported)))
    out += docker_kept()
    return out


def docker_kept():
    r = run(['docker', 'system', 'df', '--format', '{{json .}}'], timeout=30)
    rows = {}
    for line in r['out'].splitlines():
        try:
            row = json.loads(line)
            rows[row['Type']] = row
        except (ValueError, KeyError, TypeError):
            continue
    out = []
    volumes = rows.get('Local Volumes')
    if volumes and volumes.get('TotalCount') not in ('0', 0):
        out.append(result('docker', f'Docker volumes ({volumes["TotalCount"]})', 'kept',
                          'hold databases and app data', docker_size(volumes.get('Size'))))
    stopped = run(['docker', 'ps', '-aq', '--filter', 'status=exited', '--filter', 'status=created'], timeout=20)
    count = len(stopped['out'].split()) if stopped['code'] == 0 else 0
    if count:
        out.append(result('docker', f'Stopped Docker containers ({count})', 'kept',
                          'their writable layers may hold data', docker_size((rows.get('Containers') or {}).get('Reclaimable'))))
    return out


def docker_size(text):
    m = re.match(r'([\d.]+)\s*([kKMGT]?B)', text or '')
    return int(float(m[1]) * UNITS[m[2]]) if m else None


def stale_children(directory, days):
    cutoff = time.time() - days * DAY
    try:
        return [p for p in directory.iterdir() if p.is_dir() and not p.is_symlink() and newest_mtime(p) < cutoff]
    except OSError:
        return []


def remove_tree(path, root):
    def rm():
        shutil.rmtree(path)
    _, gained = freed(root, rm)
    return gained


def derived_data(home, root, deep, dry_run):
    directory = home / 'Library' / 'Developer' / 'Xcode' / 'DerivedData'
    days = 0 if deep else 14
    label = 'Xcode DerivedData' + ('' if deep else ' untouched for 14+ days')
    if not directory.is_dir():
        return result('xcode', label, 'skipped', 'no DerivedData folder')
    if busy(XCODE_BUSY):
        return result('xcode', label, 'skipped', 'Xcode is building or open')
    targets = stale_children(directory, days)
    if not targets:
        return result('xcode', label, 'skipped', 'nothing old enough')
    if dry_run:
        return result('xcode', label, 'planned', f'{len(targets)} folders')
    try:
        gained = sum(remove_tree(p, root) for p in targets)
    except OSError as exc:
        return result('xcode', label, 'failed', exc.strerror or 'removal failed')
    return result('xcode', label, 'done', f'{len(targets)} folders', gained)


def disposable(home, paths, cwds, root, dry_run):
    """Configured build-output folders, removed when untouched for 14 days and not in use."""
    out = []
    for value in paths:
        p = Path(value).expanduser()
        label = str(p).replace(str(home), '~', 1)
        if not p.exists():
            continue
        if p.is_symlink() or not p.is_dir() or home not in p.parents:
            out.append(result('other', label, 'skipped', 'not a real folder under your home'))
        elif in_git_checkout(p):
            out.append(result('other', label, 'skipped', 'inside a Git checkout; worktrees go through ADW or wt'))
        elif cwds is None or any((c + '/').startswith(str(p) + '/') for c in cwds):
            out.append(result('other', label, 'skipped', 'in use by a running process'))
        elif newest_mtime(p) > time.time() - 14 * DAY:
            out.append(result('other', label, 'skipped', 'changed in the last 14 days'))
        elif dry_run:
            out.append(result('other', label, 'planned', 'remove folder'))
        else:
            try:
                out.append(result('other', label, 'done', 'removed folder', remove_tree(p, root)))
            except OSError as exc:
                out.append(result('other', label, 'failed', exc.strerror or 'removal failed'))
    return out


def in_git_checkout(path):
    """True when path is, contains, or sits inside a Git checkout. Such folders are never deleted directly."""
    if any((p / '.git').exists() for p in (path, *path.parents)):
        return True
    return run(['find', str(path), '-maxdepth', '4', '-name', '.git', '-print', '-quit'], timeout=20)['out'].strip() != ''


def playwright_kept(home):
    p = home / 'Library' / 'Caches' / 'ms-playwright'
    size = du(p) if p.is_dir() else 0
    if size:
        return [result('caches', 'Playwright browsers', 'kept', 'installed browsers that tests need', size)]
    return []
