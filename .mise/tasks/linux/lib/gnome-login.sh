#!/usr/bin/env bash
# Remote helper for linux:unlock. Invoked as the normal desktop user over SSH.
set -euo pipefail

fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Linux && $EUID != 0 ]] || fail 'Connect as the normal Linux desktop user, not root.'
for cmd in ghostty gnome-session-inhibit gdbus python3 flock systemctl; do
  command -v "$cmd" >/dev/null || fail "Missing required desktop command: $cmd"
done
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$UID}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
exec 9>"$XDG_RUNTIME_DIR/dotfiles-gnome-login.lock"
flock -n 9 || fail 'Another GNOME login task is already running.'

mkdir -p "$HOME/.local/bin" "$HOME/.config/autostart"
cat > "$HOME/.local/bin/gnome-inhibit-and-lock" <<'INHIBIT'
#!/usr/bin/env bash
set -euo pipefail
exec 8>"${XDG_RUNTIME_DIR:-/run/user/$UID}/gnome-inhibit-and-lock.lock"
flock -n 8 || exit 0
echo 'Keeping GNOME awake behind the lock screen. Leave this terminal running.'
# The child runs after the GNOME inhibitor is acquired. Locking explicitly
# still works while idle inhibition prevents automatic idle/lock actions.
exec gnome-session-inhibit --app-id=local.gnome-inhibit-and-lock \
  --reason='Keep remote GNOME apps running behind a locked screen' \
  --inhibit=idle --inhibit=suspend \
  sh -c 'gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock || exit 1; exec sleep infinity'
INHIBIT
chmod 755 "$HOME/.local/bin/gnome-inhibit-and-lock"
python3 - <<'PY'
from pathlib import Path
helper = str(Path.home() / '.local/bin/gnome-inhibit-and-lock')
helper = helper.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
(Path.home() / '.config/autostart/gnome-inhibit-and-lock.desktop').write_text(
    '[Desktop Entry]\nType=Application\nName=Keep GNOME awake and lock screen\n'
    f'Exec=ghostty -e "{helper}"\nTerminal=false\nOnlyShowIn=GNOME;\n'
    'X-GNOME-Autostart-enabled=true\n')
PY

session_call() {
  local method=$1
  shift
  gdbus call --session --dest org.gnome.SessionManager \
    --object-path /org/gnome/SessionManager --method "org.gnome.SessionManager.$method" "$@"
}
gnome_running() {
  session_call IsSessionRunning 2>/dev/null | grep -q '(true,)'
}
screen_call() {
  gdbus call --session --dest org.gnome.ScreenSaver \
    --object-path /org/gnome/ScreenSaver --method "org.gnome.ScreenSaver.$1"
}

runtime_dir=
runtime_changed=false
cleanup() {
  if [[ -n $runtime_dir ]]; then
    if [[ $runtime_changed == true ]]; then
      if sudo test -f "$runtime_dir/original"; then
        sudo cp -p "$runtime_dir/original" "$gdm_runtime/custom.conf"
      else
        sudo rm -f "$gdm_runtime/custom.conf"
      fi
    fi
    sudo rm -rf -- "$runtime_dir"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

if ! gnome_running; then
  # Only start the local GNOME desktop from GDM's greeter. Do not interrupt an
  # existing desktop, including Sway on seat0 or a session for another user.
  for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
    seat=$(loginctl show-session "$session" -p Seat --value)
    class=$(loginctl show-session "$session" -p Class --value)
    [[ $seat != seat0 || $class != user ]] || fail 'An existing seat0 desktop is active; leaving it untouched.'
  done
  if [[ -d /etc/gdm3 ]]; then
    gdm_runtime=/run/gdm3
  elif [[ -d /etc/gdm ]]; then
    gdm_runtime=/run/gdm
  else
    fail 'GDM configuration not found; this task requires a GNOME/GDM host.'
  fi
  echo 'Starting GNOME through a temporary GDM automatic login; sudo may request your account password.'
  sudo -v
  sudo install -d -m 755 "$gdm_runtime"
  runtime_dir=$(sudo mktemp -d "$gdm_runtime/dotfiles-login.XXXXXX")
  if sudo test -e "$gdm_runtime/custom.conf"; then
    sudo cp -p "$gdm_runtime/custom.conf" "$runtime_dir/original"
  fi
  runtime_changed=true
  sudo python3 - "$gdm_runtime/custom.conf" "$(id -un)" <<'PY'
import configparser
import os
from pathlib import Path
import sys
p = Path(sys.argv[1])
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
if p.exists():
    c.read(p)
if not c.has_section('daemon'):
    c.add_section('daemon')
c['daemon']['AutomaticLoginEnable'] = 'True'
c['daemon']['AutomaticLogin'] = sys.argv[2]
with p.open('w') as f:
    c.write(f)
os.chmod(p, 0o644)
PY
  sudo systemctl restart display-manager.service
  deadline=$((SECONDS + 90))
  until gnome_running; do
    (( SECONDS < deadline )) || fail 'GNOME did not start within 90 seconds; restoring GDM configuration.'
    sleep 2
  done
  cleanup
  runtime_dir=
fi

# Autostart normally launches Ghostty. If GNOME was already running, start the
# same helper using its imported graphical environment. The helper is singleton.
inhibitor_running() {
  pgrep -u "$UID" -f '(^|/)gnome-session-inhibit --app-id=local.gnome-inhibit-and-lock' >/dev/null
}
if ! inhibitor_running; then
  systemd-run --user --collect --property=PartOf=graphical-session.target \
    ghostty -e "$HOME/.local/bin/gnome-inhibit-and-lock"
fi
deadline=$((SECONDS + 30))
until inhibitor_running && session_call IsInhibited 4 2>/dev/null | grep -q '(true,)' && \
      session_call IsInhibited 8 2>/dev/null | grep -q '(true,)'; do
  (( SECONDS < deadline )) || fail 'GNOME started, but idle/suspend inhibition could not be verified.'
  sleep 1
done
screen_call Lock >/dev/null
deadline=$((SECONDS + 15))
until screen_call GetActive 2>/dev/null | grep -q '(true,)'; do
  (( SECONDS < deadline )) || fail 'GNOME screen lock could not be verified.'
  sleep 1
done
echo 'GNOME is running with idle/suspend inhibited and the screen locked.'
echo 'Keep the Ghostty inhibitor window open. Apps using the login keyring may still require its password.'
