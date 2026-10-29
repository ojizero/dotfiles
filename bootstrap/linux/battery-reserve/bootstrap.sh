#!/bin/bash
# Opt in on a fresh machine; maintain an installed policy on repeat bootstrap.
set -euo pipefail
case "${DOTFILES_BATTERY_RESERVE:-auto}" in
    1) ;;
    0) exit 0 ;;
    auto) [[ -f /etc/battery-reserve.conf ]] || exit 0 ;;
    *) printf '%s\n' 'DOTFILES_BATTERY_RESERVE must be 1, 0, or auto' >&2; exit 1 ;;
esac
policy_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sudo /usr/bin/python3 "${policy_dir}/install.py"
