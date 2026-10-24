#!/bin/bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec 9>/run/mac-fan-overnight-setup.lock
flock -n 9 || { echo 'Another fan setup is running.' >&2; exit 1; }
backup=/var/backups/mac-quiet-fans-original
targets=(
  /usr/local/lib/mac-quiet-fans/controller.py
  /etc/systemd/system/mac-quiet-fans.service
  /usr/lib/systemd/system-sleep/mac-quiet-fans
)

# Snapshot once, before stopping a previously installed Quiet service. Preserve
# original files, modes and service state on subsequent package updates.
backup_originals() {
  [[ ! -e "$backup" ]] || return 0
  mkdir -p /var/backups
  local staging target
  staging=$(mktemp -d /var/backups/mac-quiet-fans-original.XXXXXX)
  chmod 0700 "$staging"
  for target in "${targets[@]}"; do
    mkdir -p "$staging/files$(dirname -- "$target")"
    if [[ -e "$target" ]]; then
      cp -p -- "$target" "$staging/files$target"
    fi
  done
  if systemctl is-enabled --quiet mac-quiet-fans.service; then
    touch "$staging/enabled"
  fi
  if systemctl is-active --quiet mac-quiet-fans.service; then
    touch "$staging/active"
  fi
  touch "$staging/complete"
  mv -- "$staging" "$backup"
}

case "${1:-}" in
  --rollback)
    [[ $# -eq 1 && -f "$backup/complete" ]] || {
      echo 'No complete original backup available.' >&2; exit 1;
    }
    for target in "${targets[@]}"; do
      [[ ! -L "$target" ]] || { echo "Refusing symlink: $target" >&2; exit 1; }
    done
    # ExecStopPost releases only this controller's owned override. If release
    # fails, stop here rather than replacing files while control is unresolved.
    systemctl disable --now mac-quiet-fans.service
    [[ $(cat /sys/module/macsmc_hwmon/parameters/fan_control) == N ]] || {
      echo 'Manual override still active; inspect before rollback.' >&2; exit 1;
    }
    for target in "${targets[@]}"; do
      if [[ -f "$backup/files$target" ]]; then
        mkdir -p "$(dirname -- "$target")"
        cp -p -- "$backup/files$target" "$target"
      else
        rm -f -- "$target"
      fi
    done
    systemctl daemon-reload
    if [[ -f "$backup/enabled" ]]; then
      systemctl enable mac-quiet-fans.service
    fi
    if [[ -f "$backup/active" ]]; then
      systemctl start mac-quiet-fans.service
    fi
    echo "Original files and service state restored; backup retained at $backup."
    exit 0
    ;;
  '') [[ $# -eq 0 ]] || { echo 'Unexpected empty argument.' >&2; exit 1; } ;;
  *) echo 'Usage: install-quiet-fans.sh [--rollback]' >&2; exit 1 ;;
esac
[[ $(cat /sys/class/dmi/id/product_name) == MacBookPro16,1 ]] || {
  echo 'This installer is scoped to MacBookPro16,1.' >&2; exit 1;
}
for file in mac-quiet-fans.py mac-quiet-fans.service mac-quiet-fans-sleep; do
  [[ -f "$source_dir/$file" ]] || { echo "Missing source: $file" >&2; exit 1; }
done
for target in "${targets[@]}"; do
  [[ ! -L "$target" ]] || { echo "Refusing symlink: $target" >&2; exit 1; }
done
[[ ! -e "$backup" || -f "$backup/complete" ]] || {
  echo 'Incomplete original backup; inspect before installing.' >&2; exit 1;
}
for unit in mac-fan-overnight.service mac-fan-daytime.service neofand.service t2fanrd.service mbpfan.service macfanctld.service fancontrol.service; do
  if systemctl is-active --quiet "$unit"; then
    echo "Another fan controller is active: $unit" >&2; exit 1
  fi
done
/usr/bin/python3 "$source_dir/mac-quiet-fans.py" --check
backup_originals
if systemctl is-active --quiet mac-quiet-fans.service; then
  systemctl stop mac-quiet-fans.service
fi
[[ $(cat /sys/module/macsmc_hwmon/parameters/fan_control) == N ]] || {
  echo 'Unrecognized manual override; refusing to replace it.' >&2; exit 1;
}
install -d -o root -g root -m 0755 /usr/local/lib/mac-quiet-fans
install -o root -g root -m 0755 "$source_dir/mac-quiet-fans.py" /usr/local/lib/mac-quiet-fans/controller.py
install -o root -g root -m 0644 "$source_dir/mac-quiet-fans.service" /etc/systemd/system/mac-quiet-fans.service
install -o root -g root -m 0755 "$source_dir/mac-quiet-fans-sleep" /usr/lib/systemd/system-sleep/mac-quiet-fans
systemd-analyze verify /etc/systemd/system/mac-quiet-fans.service
systemctl daemon-reload
systemctl enable --now mac-quiet-fans.service
sleep 3
systemctl --no-pager --full status mac-quiet-fans.service
cat /run/mac-quiet-fans/status.json
echo 'Persistent Quiet curve enabled at boot; released before sleep and resumed afterward.'
echo 'Disable and restore firmware: sudo systemctl disable --now mac-quiet-fans.service'
