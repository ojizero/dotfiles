#!/bin/bash
# Run as the desktop user, only when ready for the agreed brief interruption.
set -euo pipefail
# Use the system GLib tools and this user's session bus, including from T3.
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
sudo -v
locked() {
    /usr/bin/gdbus call --session --timeout 3 --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive \
        | /usr/bin/grep -q '(true,)'
}
printf '%s\n' 'Controlled test: locking now; close lid within 20 seconds.' \
    'Keep charger disconnected. Reconnect it 60 seconds from now.'
if ! locked; then
    # A timeout may still mean Lock succeeded; query state instead of retrying.
    /usr/bin/gdbus call --session --timeout 5 --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock \
        >/dev/null 2>&1 || true
fi
deadline=$((SECONDS + 15))
until locked; do
    if (( SECONDS >= deadline )); then
        printf '%s\n' 'Screen lock unverified; test cancelled.' >&2
        exit 1
    fi
    sleep 1
done
sleep 20
if ! locked; then
    printf '%s\n' 'Screen no longer locked; test cancelled.' >&2
    exit 1
fi
lid=/proc/acpi/button/lid/LID0/state
if ! /usr/bin/grep -q closed "$lid"; then
    printf '%s\n' 'Lid is not closed; test cancelled.' >&2
    exit 1
fi
date --iso-8601=seconds
sudo -n /usr/local/libexec/battery-reserve --test-suspend
