#!/usr/bin/env python3
"""Autonomous macOS housekeeping: measure, clean what is provably safe, record history, write an HTML report."""
import argparse
import fcntl
import json
import os
import platform
import stat
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import clean
import measure
import report
import worktrees

DISK_ROOT = '/System/Volumes/Data'
HISTORY_LINES = 500
SIZE_BUDGET = 60
OPTIONS = {'warning_percent': 15, 'urgent_gib': 25, 'repositories': [], 'disposable': [], 'skip': [], 'state_dir': None}
SKIPPABLE = {'brew', 'uv', 'pnpm', 'simulators', 'docker', 'xcode', 'worktrees', 'deep'}


def load_config(path):
    """Optional config. A missing file means defaults; a present but invalid one stops the run."""
    if not path.exists():
        return dict(OPTIONS)
    s = path.stat()
    if not stat.S_ISREG(s.st_mode) or s.st_uid != os.getuid() or s.st_mode & 0o022:
        raise ValueError(f'{path} must be a regular file you own, not writable by others')
    c = json.loads(path.read_text())
    unknown = set(c) - set(OPTIONS)
    if unknown:
        raise ValueError('unknown config keys: ' + ', '.join(sorted(unknown)))
    c = {**OPTIONS, **c}
    if not (isinstance(c['warning_percent'], (int, float)) and 1 <= c['warning_percent'] <= 90):
        raise ValueError('warning_percent must be between 1 and 90')
    if not (isinstance(c['urgent_gib'], (int, float)) and 1 <= c['urgent_gib'] <= 1024):
        raise ValueError('urgent_gib must be between 1 and 1024')
    for key in ('repositories', 'disposable', 'skip'):
        if not isinstance(c[key], list) or not all(isinstance(x, str) for x in c[key]):
            raise ValueError(key + ' must be a list of strings')
    if set(c['skip']) - SKIPPABLE:
        raise ValueError('skip accepts: ' + ', '.join(sorted(SKIPPABLE)))
    return c


def tool_path(home):
    """Scheduled runs may start with a minimal PATH; add the usual tool locations."""
    extra = [str(home / '.local/share/mise/shims'), '/opt/homebrew/bin', str(home / '.local/bin'), '/usr/local/bin']
    current = os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin').split(':')
    os.environ['PATH'] = ':'.join(current + [p for p in extra if p not in current])


def sized(items, deadline):
    """Allocated size per path, within a shared time budget. Unknown sizes stay None."""
    for item in items:
        remaining = deadline - time.monotonic()
        item['bytes'] = measure.du(item['path'], timeout=min(20, remaining)) if remaining > 1 else None
    return items


def worktree_results(home, config, cwds, root, dry_run):
    plan = worktrees.plan(home, config['repositories'], cwds)
    removed, failed, kept = [], [], {}
    for w in plan:
        short = w['path'].replace(str(home), '~', 1)
        if w['decision'] == 'remove' and time.monotonic() > clean.DEADLINE:
            w['reason'] = 'run time budget used up; the next run continues'
        if w['decision'] == 'remove' and len(removed) + len(failed) < worktrees.MAX_REMOVALS and not failed \
                and not w['reason']:
            if dry_run:
                removed.append({'path': short, 'bytes': None, 'note': f'{w["manager"]}, {w["merged"]}'})
                continue
            error, gained = clean.freed(root, lambda: worktrees.remove(w))
            if error:
                failed.append({'path': short, 'bytes': None, 'note': error})
            else:
                removed.append({'path': short, 'bytes': gained, 'note': f'{w["manager"]}, {w["merged"]}'})
        else:
            reason = w['reason'] or ('stopped after a failed removal' if failed else 'per-run limit reached')
            kept.setdefault(reason, []).append({'path': w['path'], 'short': short, 'note': w.get('branch') or ''})
    out = []
    if removed:
        out.append({**clean.result('worktrees', f'Finished worktrees ({len(removed)})', 'planned' if dry_run else 'done',
                                   'removed with ADW or wt', None if dry_run else sum(x['bytes'] for x in removed)),
                    'items': removed})
    for item in failed:
        out.append({**clean.result('worktrees', 'Worktree ' + item['path'], 'failed', item['note']), 'items': []})
    deadline = min(time.monotonic() + SIZE_BUDGET, clean.DEADLINE + 30)
    for reason, items in sorted(kept.items(), key=lambda kv: -len(kv[1])):
        if not reason.startswith('T3 Code'):
            sized(items, deadline)
        sizes = [x.get('bytes') for x in items]
        known = sum(s for s in sizes if s)
        out.append({**clean.result('worktrees', f'Worktrees ({len(items)})', 'kept', reason, known or None),
                    'partial': None in sizes and known > 0,
                    'items': [{'path': x['short'], 'bytes': x.get('bytes'), 'note': x['note']} for x in items]})
    if not plan:
        out.append(clean.result('worktrees', 'Worktrees', 'skipped', 'no ADW projects or repositories found'))
    return out


def cleanup(home, config, root, dry_run, thresholds):
    """Routine steps every run; deep steps only while disk space is low. Steps past the time budget are skipped."""
    skip = set(config['skip'])
    cwds = measure.process_cwds()
    results = []

    def step(key, category, label, fn):
        if key in skip:
            results.append(clean.result(category, label, 'skipped', 'turned off in config'))
        elif time.monotonic() > clean.DEADLINE:
            results.append(clean.result(category, label, 'skipped', 'run time budget used up; the next run continues'))
        else:
            value = fn()
            results.extend(value if isinstance(value, list) else [value])

    step('docker', 'docker', 'Docker', lambda: clean.docker(root, False, dry_run))
    step('worktrees', 'worktrees', 'Worktrees', lambda: worktree_results(home, config, cwds, root, dry_run))
    for spec in clean.ROUTINE:
        step(spec[0], spec[1], spec[2], lambda spec=spec: clean.tool_action(spec, root, dry_run))
    step('xcode', 'xcode', 'Xcode DerivedData', lambda: clean.derived_data(home, root, False, dry_run))

    now = measure.disk(root)
    low = measure.status(now['free_bytes'], now['capacity_bytes'], *thresholds) != 'healthy'
    if not low:
        results.append(clean.result('caches', 'Full cache clear (uv, Bun, npm, NuGet, Go, Docker build cache, '
                                    'DerivedData)', 'skipped', 'only runs when free space is low'))
    else:
        for spec in clean.DEEP:
            step('deep', spec[1], spec[2], lambda spec=spec: clean.tool_action(spec, root, dry_run))
        if 'docker' not in skip:
            step('deep', 'docker', 'Docker build cache',
                 lambda: [r for r in clean.docker(root, True, dry_run) if r['outcome'] != 'kept'])
        if 'xcode' not in skip:
            step('deep', 'xcode', 'Xcode DerivedData', lambda: clean.derived_data(home, root, True, dry_run))
        step('deep', 'other', 'Configured build folders',
             lambda: clean.disposable(home, config['disposable'], cwds, root, dry_run))
    results.extend(clean.playwright_kept(home))
    return results, low


def read_history(path):
    try:
        lines = path.read_text().splitlines()[-HISTORY_LINES:]
    except OSError:
        return []
    out = []
    for line in lines:
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def append_history(path, entry, history):
    lines = [json.dumps(x, separators=(',', ':')) for x in (history + [entry])[-HISTORY_LINES:]]
    write_private(path, '\n'.join(lines) + '\n')


def write_private(path, text):
    tmp = path.with_suffix(path.suffix + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(text)
    os.replace(tmp, path)


def gib(n):
    return f'{n / measure.GIB:.1f} GiB'


def summary(record, html_path):
    counts = record['counts']
    lines = [f'Housekeeping {"dry run " if record["dry_run"] else ""}finished. Disk status: {record["status_after"]}'
             f' (was {record["status_before"]}). Memory pressure: {record["memory"]["pressure"]}.',
             ('Dry run: nothing was removed.' if record['dry_run'] else f'Freed {gib(record["freed_bytes"])}.') +
             f' Free space {gib(record["free_before"])} -> {gib(record["free_after"])} of {gib(record["capacity"])}.',
             f'Done {counts["done"]}, kept for review {counts["kept"]}, skipped {counts["skipped"]}, '
             f'failed {counts["failed"]}' + (f', planned {counts["planned"]}' if record['dry_run'] else '') + '.']
    lines += [f'FAILED: {r["label"]}: {r["reason"]}' for r in record['results'] if r['outcome'] == 'failed']
    lines.append(f'Report: {html_path}')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='plan only; remove nothing and record no history')
    parser.add_argument('--config', type=Path, default=Path.home() / '.config' / 'housekeeping.json')
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        print('Housekeeping supports macOS only. Nothing was done.')
        return 2
    home = Path.home()
    try:
        config = load_config(args.config)
    except (OSError, ValueError) as exc:
        print(f'Housekeeping did not run: invalid config. {exc}')
        return 2
    tool_path(home)
    state = Path(config['state_dir']).expanduser() if config['state_dir'] else \
        home / 'Library' / 'Application Support' / 'housekeeping'
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock = open(state / 'lock', 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print('Housekeeping did not run: another run is in progress.')
        return 2

    thresholds = (config['warning_percent'], config['urgent_gib'])
    clean.DEADLINE = time.monotonic() + clean.BUDGET
    started = datetime.now(timezone.utc)
    before = measure.disk(DISK_ROOT)
    results, deep = cleanup(home, config, DISK_ROOT, args.dry_run, thresholds)
    after = measure.disk(DISK_ROOT)
    freed = {}
    for r in results:
        if r['outcome'] == 'done' and r['bytes']:
            freed[r['category']] = freed.get(r['category'], 0) + r['bytes']
    record = {
        'date': started.isoformat(timespec='seconds'), 'host': os.uname().nodename.split('.')[0],
        'dry_run': args.dry_run, 'deep': deep, 'capacity': after['capacity_bytes'],
        'free_before': before['free_bytes'], 'free_after': after['free_bytes'],
        'status_before': measure.status(before['free_bytes'], before['capacity_bytes'], *thresholds),
        'status_after': measure.status(after['free_bytes'], after['capacity_bytes'], *thresholds),
        'thresholds': {'warning_percent': thresholds[0], 'urgent_gib': thresholds[1]},
        'freed': freed, 'freed_bytes': sum(freed.values()),
        'seconds': round((datetime.now(timezone.utc) - started).total_seconds()),
        'counts': {k: sum(r['outcome'] == k for r in results) for k in ('done', 'kept', 'skipped', 'failed', 'planned')},
        'memory': measure.memory(), 'results': results,
    }
    history_path = state / 'history.jsonl'
    history = read_history(history_path)
    if not args.dry_run:
        entry = {k: record[k] for k in ('date', 'capacity', 'free_before', 'free_after', 'status_after', 'freed', 'counts')}
        append_history(history_path, entry, history)
        history.append(entry)
    html_path = state / ('dry-run.html' if args.dry_run else 'report.html')
    write_private(html_path, report.render(record, history))
    write_private(state / ('dry-run.json' if args.dry_run else 'last-run.json'), json.dumps(record, indent=1))
    print(summary(record, html_path))
    return 1 if record['counts']['failed'] else 0


if __name__ == '__main__':
    sys.exit(main())
