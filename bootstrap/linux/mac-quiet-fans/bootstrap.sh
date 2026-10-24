#!/bin/bash
# Fresh machines opt in; maintain only an installed, enabled Quiet controller.
set -euo pipefail
case "${DOTFILES_MAC_QUIET_FANS:-auto}" in
    1) ;;
    0) exit 0 ;;
    auto)
        [[ -f /etc/systemd/system/mac-quiet-fans.service ]] || exit 0
        systemctl is-enabled --quiet mac-quiet-fans.service || exit 0
        ;;
    *) printf '%s\n' 'DOTFILES_MAC_QUIET_FANS must be 1, 0, or auto' >&2; exit 1 ;;
esac
package_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sudo bash "${package_dir}/install-quiet-fans.sh"
