#!/usr/bin/env -S uv run --no-cache --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Read-only storage diagnostics: disk and memory health, and where the space goes. Removes nothing."""
import argparse
import json
import shutil
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import housekeeping
import measure
from housekeeping import gib

BUDGET = 90
# (label, path under $HOME, what housekeeping does with it). Paths macOS guards with a permission prompt
# (Downloads, Documents, other apps' containers) are left out so a check never triggers one.
LOCATIONS = [
    ('Homebrew downloads', 'Library/Caches/Homebrew', 'pruned every run'),
    ('uv cache', '.cache/uv', 'pruned every run, cleared when low'),
    ('pnpm store', 'Library/pnpm/store', 'pruned every run'),
    ('npm cache', '.npm', 'cleared when low'),
    ('Bun cache', '.bun/install/cache', 'cleared when low'),
    ('Go build cache', 'Library/Caches/go-build', 'cleared when low'),
    ('NuGet packages', '.nuget/packages', 'cleared when low'),
    ('Xcode DerivedData', 'Library/Developer/Xcode/DerivedData', '14+ days every run, all when low'),
    ('iOS simulators', 'Library/Developer/CoreSimulator', 'unavailable ones every run'),
    ('Xcode device support', 'Library/Developer/Xcode/iOS DeviceSupport', 'left alone'),
    ('Xcode archives', 'Library/Developer/Xcode/Archives', 'left alone'),
    ('Playwright browsers', 'Library/Caches/ms-playwright', 'left alone'),
    ('All of ~/Library/Caches', 'Library/Caches', 'partly, see above'),
    ('T3 Code worktrees', '.t3/worktrees', 'left alone; T3 manages them'),
    ('ADW projects and worktrees', '.adw/projects', 'merged worktrees every run'),
    ('mise tools', '.local/share/mise', 'left alone'),
    ('Trash', '.Trash', 'left alone'),
]


def tool_dir(argv):
    r = measure.run(argv, timeout=10) if shutil.which(argv[0]) else {'code': 1}
    return r['out'].strip() if r['code'] == 0 else None


def breakdown(home):
    paths = {label: home / rel for label, rel, _ in LOCATIONS}
    # Tools report their own locations when moved from the defaults.
    for label, argv in (('uv cache', ['uv', 'cache', 'dir']), ('Homebrew downloads', ['brew', '--cache'])):
        paths[label] = Path(tool_dir(argv) or paths[label])
    found = [(label, paths[label], note) for label, _, note in LOCATIONS if paths[label].is_dir()]
    with ThreadPoolExecutor(6) as pool:
        sizes = pool.map(lambda x: measure.du(x[1], timeout=BUDGET), found)
    return sorted(((label, path, note, size) for (label, path, note), size in zip(found, sizes)),
                  key=lambda x: -(x[3] or 0))


def docker():
    if not shutil.which('docker') or measure.run(['docker', 'info', '--format', '{{.ServerVersion}}'], timeout=20)['code']:
        return ['Docker: not running, so its disk use is unknown (housekeeping leaves it stopped too).']
    r = measure.run(['docker', 'system', 'df', '--format', '{{json .}}'], timeout=30)
    lines = ['Docker (images and build cache unused 7+ days are pruned every run; volumes and containers never):']
    for line in r['out'].splitlines():
        try:
            row = json.loads(line)
            lines.append(f'  {row["Size"]:>10}  {row["Type"]} ({row["TotalCount"]}), reclaimable {row["Reclaimable"]}')
        except (ValueError, KeyError):
            continue
    return lines


def snapshots():
    r = measure.run(['/usr/bin/tmutil', 'listlocalsnapshots', '/'], timeout=20)
    count = sum('com.apple' in line for line in r['out'].splitlines()) if r['code'] == 0 else None
    return 'APFS local snapshots: ' + ('unknown' if count is None else str(count)) + \
        ' (macOS frees these itself; housekeeping leaves them alone)'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=housekeeping.CONFIG)
    args = parser.parse_args()
    try:
        config = housekeeping.load_config(args.config)
    except (OSError, ValueError) as exc:
        print(f'Invalid config: {exc}')
        return 2
    home = Path.home()
    housekeeping.tool_path(home)
    d = measure.disk(housekeeping.DISK_ROOT)
    thresholds = (config['warning_percent'], config['urgent_gib'])
    state = measure.status(d['free_bytes'], d['capacity_bytes'], *thresholds)
    print(f'Disk: {gib(d["free_bytes"])} free of {gib(d["capacity_bytes"])} '
          f'({d["free_bytes"] / d["capacity_bytes"] * 100:.0f}%), {state}. Low-space lines: '
          f'below {thresholds[0]}% or {thresholds[1]} GiB free.')
    mem = measure.memory()
    swap = gib(mem['swap_bytes']) if mem['swap_bytes'] is not None else 'unknown'
    top = ', '.join(f'{p["name"]} {p["rss_bytes"] / measure.GIB:.1f} GiB' for p in mem['top_processes'][:3])
    print(f'Memory pressure: {mem["pressure"]}, swap used {swap}. Largest processes: {top}.')
    print(snapshots())
    print('\n'.join(docker()))
    print('Space by location, largest first (what housekeeping does with it):')
    for label, path, note, size in breakdown(home):
        shown = gib(size) if size is not None else 'unknown'
        print(f'  {shown:>10}  {label}  {str(path).replace(str(home), "~", 1)}  ({note})')
    print('For worktrees and everything the last run kept, see: mise run housekeeping:status')
    return 0


if __name__ == '__main__':
    sys.exit(main())
