#!/usr/bin/python3
"""Install in observation mode, or restore the original system configuration."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

SOURCE = Path(__file__).resolve().parent
BACKUP = Path('/var/backups/battery-reserve-original')
FILES = {
    '/usr/local/libexec/battery-reserve': ('battery-reserve', 0o755),
    '/usr/local/libexec/battery-reserve-wake': ('battery-reserve-wake', 0o755),
    '/etc/battery-reserve.conf': ('battery-reserve.conf', 0o644),
    '/etc/systemd/system/battery-reserve.service': ('battery-reserve.service', 0o644),
    '/etc/systemd/system/battery-reserve.timer': ('battery-reserve.timer', 0o644),
    '/etc/systemd/system/battery-reserve-wake.service': ('battery-reserve-wake.service', 0o644),
    '/etc/systemd/logind.conf.d/70-battery-reserve.conf': ('70-battery-reserve.conf', 0o644),
}
UPOWER = Path('/etc/UPower/UPower.conf')
WAKE = ['/sys/class/power_supply/macsmc-ac/power/wakeup',
        '/sys/class/power_supply/macsmc-battery/power/wakeup',
        '/sys/devices/platform/ACPI0003:00/power/wakeup']


def run(*args, check=True):
    return subprocess.run(args, check=check)


def backup():
    if (BACKUP / 'manifest.json').exists():
        return
    BACKUP.mkdir(mode=0o700, parents=True, exist_ok=True)
    manifest = {'files': {}, 'wake': {}}
    for name in [*FILES, str(UPOWER)]:
        p = Path(name)
        if p.is_symlink():
            raise RuntimeError(f'refusing to replace symlink: {p}')
        manifest['files'][name] = p.exists()
        if p.exists():
            dest = BACKUP / p.relative_to('/')
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)
    for name in WAKE:
        if Path(name).exists():
            manifest['wake'][name] = Path(name).read_text().strip()
    manifest['units'] = {}
    for unit in ('battery-reserve.timer', 'battery-reserve-wake.service'):
        manifest['units'][unit] = {
            'enabled': subprocess.run(['systemctl', 'is-enabled', unit], capture_output=True,
                                      text=True).stdout.strip() == 'enabled',
            'active': subprocess.run(['systemctl', 'is-active', unit], capture_output=True,
                                     text=True).stdout.strip() == 'active'}
    (BACKUP / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


def rollback():
    m = json.loads((BACKUP / 'manifest.json').read_text())
    run('systemctl', 'disable', '--now', 'battery-reserve.timer', 'battery-reserve-wake.service', check=False)
    run('systemctl', 'stop', 'battery-reserve.service', check=False)
    for name, existed in m['files'].items():
        p = Path(name)
        if existed:
            shutil.copy2(BACKUP / p.relative_to('/'), p)
        else:
            p.unlink(missing_ok=True)
    for name, value in m['wake'].items():
        if Path(name).exists():
            Path(name).write_text(value + '\n')
    run('systemctl', 'daemon-reload')
    run('systemctl', 'reload', 'systemd-logind')
    run('systemctl', 'try-restart', 'upower.service')
    for unit, state in m['units'].items():
        if state['enabled']:
            run('systemctl', 'enable', unit)
        if state['active']:
            run('systemctl', 'start', unit)
    print(f'Original files and wake settings restored. Backup retained at {BACKUP}.')


def main():
    if os.geteuid() != 0:
        sys.exit('Run with sudo locally; no password is stored.')
    if sys.argv[1:] == ['--rollback']:
        rollback()
        return
    if sys.argv[1:]:
        sys.exit('Usage: install.py [--rollback]')
    if Path('/sys/class/dmi/id/product_name').read_text().strip() != 'MacBookPro16,1':
        sys.exit('This reviewed installer is scoped to MacBookPro16,1.')
    # Check all input files before touching the system.
    for source, _ in FILES.values():
        if not (SOURCE / source).is_file():
            sys.exit(f'Missing source: {source}')
    upower = UPOWER.read_text()
    upower, count = re.subn(r'(?m)^CriticalPowerAction=.*$', 'CriticalPowerAction=PowerOff', upower)
    if count != 1:
        sys.exit('Expected exactly one UPower critical action; refusing ambiguous edit.')
    backup()
    run('systemctl', 'stop', 'battery-reserve.timer', check=False)
    run('systemctl', 'stop', 'battery-reserve.service', check=False)
    for name, (source, mode) in FILES.items():
        p = Path(name)
        if p.is_symlink():
            raise RuntimeError(f'refusing symlink: {p}')
        if name == '/etc/battery-reserve.conf' and p.exists():
            continue  # Preserve threshold and arming choices on repeat installs.
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE / source, p)
        p.chmod(mode)
    UPOWER.write_text(upower)
    run('/usr/local/libexec/battery-reserve', '--dry-run')
    run('systemd-analyze', 'verify', '/etc/systemd/system/battery-reserve.service',
        '/etc/systemd/system/battery-reserve.timer', '/etc/systemd/system/battery-reserve-wake.service')
    run('systemctl', 'daemon-reload')
    run('systemctl', 'reload', 'systemd-logind')
    run('systemctl', 'try-restart', 'upower.service')
    run('systemctl', 'enable', '--now', 'battery-reserve-wake.service', 'battery-reserve.timer')
    print(f'Installed. Config preserved on repeat installs. Original backup: {BACKUP}')
    print('First installation is DISARMED: inspect /etc/battery-reserve.conf before arming.')


if __name__ == '__main__':
    main()
