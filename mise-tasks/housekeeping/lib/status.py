#!/usr/bin/env -S uv run --no-cache --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Read-only checkup: the schedule, a run in progress, and what the last run did."""
import argparse
import json
import os
import plistlib
import sys
from datetime import datetime, timezone
from pathlib import Path

import housekeeping
from housekeeping import gib
from measure import run

# Keep in sync with the `periodic` task.
LABEL = 'local.dotfiles.housekeeping'
DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']


def schedule():
    plist = Path.home() / 'Library' / 'LaunchAgents' / f'{LABEL}.plist'
    if not plist.is_file():
        return 'Schedule: not installed. Install with: mise run housekeeping:periodic'
    try:
        at = plistlib.loads(plist.read_bytes()).get('StartCalendarInterval') or {}
    except (OSError, plistlib.InvalidFileException):
        at = {}
    when = f'{DAYS[at["Weekday"] % 7]}s ' if 'Weekday' in at else 'daily '
    when += f'at {at.get("Hour", 0):02d}:{at.get("Minute", 0):02d}'
    r = run(['/bin/launchctl', 'print', f'gui/{os.getuid()}/{LABEL}'])
    if r['code'] != 0:
        return f'Schedule: {when}, but not loaded. Reload with: mise run housekeeping:periodic'
    fields = dict(line.strip().split(' = ', 1) for line in r['out'].splitlines() if ' = ' in line)
    exit_code = fields.get('last exit code', 'none yet')
    return f'Schedule: {when} (loaded, last exit code {exit_code})'


def in_progress(state):
    try:
        p = json.loads((state / 'progress.json').read_text())
    except (OSError, ValueError):
        return 'Now: idle.'
    try:
        os.kill(p['pid'], 0)
    except ProcessLookupError:
        return f'Now: idle. The run started {ago(p["started"])} did not finish; it stopped during "{p["step"]}".'
    except PermissionError:
        pass
    return f'Now: running since {ago(p["started"])}, on "{p["step"]}" (pid {p["pid"]}).'


def ago(iso):
    try:
        then = datetime.fromisoformat(iso)
    except (TypeError, ValueError):
        return 'an unknown time ago'
    hours = (datetime.now(timezone.utc) - then).total_seconds() / 3600
    text = f'{hours * 60:.0f} minutes' if hours < 1 else f'{hours:.0f} hours' if hours < 48 else f'{hours / 24:.0f} days'
    return f'{then.astimezone():%Y-%m-%d %H:%M} ({text} ago)'


def last_run(state, name, top):
    try:
        record = json.loads((state / f'{name}.json').read_text())
    except (OSError, ValueError):
        return None
    report = state / ('dry-run.html' if record['dry_run'] else 'report.html')
    lines = [f'{"Last dry run" if record["dry_run"] else "Last run"}: {ago(record["date"])}, took {record["seconds"]}s.',
             housekeeping.summary(record, report)]
    kept = sorted((r for r in record['results'] if r['outcome'] == 'kept'), key=lambda r: -(r['bytes'] or 0))[:top]
    if kept:
        lines.append('Largest things it left alone:')
        lines += [f'  {gib(r["bytes"]) if r["bytes"] else "size unknown":>12}  {r["label"]}: {r["reason"]}' for r in kept]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=housekeeping.CONFIG)
    parser.add_argument('--top', type=int, default=5, help='how many kept items to list')
    args = parser.parse_args()
    try:
        state = housekeeping.state_dir(housekeeping.load_config(args.config))
    except (OSError, ValueError) as exc:
        print(f'Invalid config: {exc}')
        return 2
    print(schedule())
    print(in_progress(state))
    real, dry = last_run(state, 'last-run', args.top), last_run(state, 'dry-run', args.top)
    print(real or 'Last run: none yet. Run now with: mise run housekeeping')
    dry_path, real_path = state / 'dry-run.json', state / 'last-run.json'
    if dry and (not real or dry_path.stat().st_mtime > real_path.stat().st_mtime):
        print(dry)
    print(f'Log of scheduled runs: {state / "scheduled.log"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
