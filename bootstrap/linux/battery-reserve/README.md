# Sagittarius A* local battery reserve

Scoped to sagittarius-a, MacBookPro16,1, Ubuntu 26.04.1, kernel
7.3.0-3-t2-resolute. Uses local macsmc AC and battery readings exclusively.
No NAS/NUT, network checks, stored passwords, hibernation, boot image changes,
or module unload hooks.

## Linux bootstrap integration

`bootstrap/linux/extras.setup` calls `battery-reserve/bootstrap.sh`. It runs
the same reviewed installer when `/etc/battery-reserve.conf` already exists,
or when `DOTFILES_BATTERY_RESERVE=1` opts in on a fresh machine. Other desktops
skip it by default. Set `DOTFILES_BATTERY_RESERVE=0` to skip it explicitly.
The optional `[env]` entry is documented in `.mise.local.toml.sample`.
For a fresh device, select `linux-desktop` and opt in, for example:

```sh
DOTFILES_BATTERY_RESERVE=1 MISE_ENV=linux-desktop bootstrap/install.sh
```

The installer checks the hardware model and installs disarmed. Complete the
controlled test below and arm `/etc/battery-reserve.conf` separately. Repeat
bootstrap preserves the existing threshold and arming choice, enables its
units, and preserves the original rollback backup. To retain a temporarily
disabled timer across bootstrap, explicitly skip this step with value 0;
`armed=false` also remains disarmed through bootstrap.

The GNOME `local.gnome-inhibit-and-lock` process is an existing separate
desktop setup, not created by this installer. Its deployment is already
tracked on origin/master in `.mise/tasks/linux/lib/gnome-login.sh` (commits
93aa354 and 38bf395), used by `mise linux:unlock <device>` from the originating
machine. On a replacement machine, run that existing workflow to reestablish
GNOME's autostart/inhibitor before relying on uninterrupted operation above
reserve; the system reserve service itself does not require GNOME.

## Closed-lid suspend guard

The package also installs the root system service
`closed-lid-suspend-guard.service` under `multi-user.target`. Its script reads
`/proc/acpi/button/lid/LID0/state` every 0.25 seconds. While closed, it holds a
block inhibitor for `sleep:idle:handle-suspend-key:handle-hibernate-key`, named
`Closed lid battery reserve policy`. Opening the lid releases this guard's
inhibitor. Other sleep settings and existing GNOME inhibitors still apply.
The child inhibitor is supervised; child or lid-read failure exits the guard,
and systemd restarts it after three seconds.

The policy is to stay awake with the lid closed until the battery reserve
requests suspend, then use the previously tested charger wake path. The root
reserve request still uses `systemctl --check-inhibitors=no suspend` and can
bypass this guard without stopping it. Root ownership makes the guard
independent of login and GNOME, not absolute enforcement: privileged commands
can explicitly bypass inhibitors. Polling introduces a small transition delay;
there are also gaps during service start or failure recovery.

The installer copies only the system guard: script mode `0755`, unit mode
`0644`, both owned by root. It starts/restarts the guard on installation and
enables it for boot. It does not install a user guard or enable linger. The
temporary user guard from the live migration is disabled; its unused files
are not part of this package. GNOME's existing workflow is unchanged.
The guard runs even while reserve suspension is disarmed; arming controls only
the battery policy's automatic suspend requests.

## Installation and status

Reviewed source lives in this directory. First installation starts DISARMED,
so installing cannot trigger this policy's suspend. Run locally:

```sh
sudo /usr/bin/python3 /home/oji/workspace/self/dotfiles/bootstrap/linux/battery-reserve/install.py
```

The installer backs up original files and wake settings to
`/var/backups/battery-reserve-original` before edits. Repeated installations
preserve that original backup and `/etc/battery-reserve.conf`, including arming.
On upgrade, the backup manifest adds snapshots for newly managed guard files
and its prior unit state without replacing any earlier original snapshots.
It installs root-owned copies rather than running files from the user's home.
It does not change the GNOME inhibitor, idle preferences, apps, or sessions.

```sh
/usr/local/libexec/battery-reserve --dry-run
systemctl status battery-reserve.timer battery-reserve-wake.service
systemctl status closed-lid-suspend-guard.service
systemd-inhibit --list --no-pager
journalctl -u battery-reserve.service -u battery-reserve-wake.service -n 30
journalctl -u closed-lid-suspend-guard.service -n 30
sudo cat /var/lib/battery-reserve/state.json
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
```

Set `armed = true` in `/etc/battery-reserve.conf` with `sudoedit` when ready.
No restart is required: each timer invocation rereads the config. Set
`threshold = 20` to change the reserve percentage (allowed range 5–80).
`debounce_seconds = 30` (15–300) and `ac_rearm_seconds = 120` (60–3600)
are configurable. Polling is every 30 seconds; the typical low-to-action delay
is 30–60 seconds, subject to scheduling and logind's sleep preparation.
If it has already observed a low battery while disarmed, arming can act on the
next tick. Check live capacity first.

## Behavior

- On AC or above reserve, no suspend request; the existing GNOME idle/suspend
  inhibitor stays alive. Explicit logind lid rules ignore the lid on both AC
  and battery, allowing closed-lid operation down to the reserve.
- Low battery must persist across the debounce interval. Invalid or missing
  readings cause no action and reset debounce and AC stability tracking.
  This fails open for availability; missing telemetry cannot protect reserve.
- AC is sampled around the capacity read and again just before requesting
  `systemctl --check-inhibitors=no suspend`. Only that request overrides sleep
  inhibitors; it does not kill the inhibitor. The tiny hardware race after
  the final read cannot be eliminated in userspace.
- A latch is persisted before the request. After wake on battery, no further
  reserve suspend is attempted, even after restarting the timer/service or
  if capacity rises above reserve. This allows a manual wake for recovery
  without a suspend loop. Battery will then continue to drain while awake:
  restore AC promptly or explicitly suspend again. A failed suspend request
  is also latched and logged; investigate rather than automatically retrying.
- AC must remain observed online for two minutes to clear the latch. Charger
  bounce does not immediately rearm. Booting starts a new latch/debounce cycle.
  An unrelated manual wake before any reserve action is not latched: normal
  threshold/debounce rules still apply.
- The timer does not run during suspend. `WakeSystem=false` deliberately makes
  no RTC wake promises. This machine's macsmc-rtc exposes no wakealarm.
- UPower retains percentage levels 20/5/2, with the final critical action made
  explicitly `PowerOff` at 2%, replacing unsupported HybridSleep. This is a
  last awake-system safety action, not RAM preservation. Its interaction with
  active inhibitors has not been hardware-tested; do not depend on it. A
  sleeping machine cannot execute UPower's action. RAM can still be lost if
  battery empties during suspend. Hibernation is not configured.

## AC wake and controlled test

The boot service enables macsmc AC/battery `power/wakeup` and the firmware AC
adapter's `/sys/devices/platform/ACPI0003:00/power/wakeup`, where present.
The latter maps to `\\_SB_.ADP1` in ACPI, initially disabled. This is an
idempotent sysfs write, not a blind `/proc/acpi/wakeup` toggle. Firmware flags
prove only that wake is enabled, not that this lid/charger arrangement wakes.

**One controlled hardware test passed; details and warnings are recorded below.
Do not run a suspend command during active work.**

1. Install disarmed. Record boot ID, GNOME session and process IDs, Wi-Fi/SSH
   state and current battery. Have physical access for fallback wake.
2. Confirm the desktop is locked using `org.gnome.ScreenSaver.GetActive`;
   do not repeat a Lock call if it already reports true. Confirm the existing
   `local.gnome-inhibit-and-lock` inhibitor is still held. Lock once only if
   necessary, then verify state regardless of a Lock method timeout.
3. With no external display, close the lid and confirm the local AC reading
   remains 0. Require user readiness before executing the following explicit
   controlled test from the agent or another terminal:

   ```sh
   bash /home/oji/workspace/self/dotfiles/bootstrap/linux/battery-reserve/controlled-test.sh
   ```

   The helper authenticates sudo locally, verifies the lock (allowing time
   for asynchronous GNOME locking), waits 20 seconds to close the lid, checks
   it is closed, then runs `/usr/local/libexec/battery-reserve --test-suspend`.
   The root test deliberately bypasses threshold, arming and latch for one
   action, requires AC offline and at least 10% battery, performs the final AC
   recheck, and sets the normal latch. Do not change the threshold just to test.
4. Leave it suspended on battery briefly (about 30 seconds), then reconnect
   the USB-C brick with lid closed. Record times and whether AC alone wakes
   it. If it stays asleep, open the lid or briefly press a key/power button
   to resume (do not hold the power button). A software poller cannot fix an
   absent hardware wake. Practical fallback: physical wake after restoration;
   another already-tested firmware wake source would need separate validation.
5. Inspect kernel and sleep logs for actual suspend entry/exit, battery change,
   and sleep duration. Verify the same boot ID, GNOME session, inhibitor and
   app PIDs survive, screen is locked, Wi-Fi reconnects, and normal SSH works
   from a separate LAN client. User confirms app interaction after unlocking.
   A successful command exit alone is not proof of any of these.
6. Optionally test manual wake on battery in a separate user-approved round:
   the state remains latched and subsequent ticks log no action. Restore AC,
   wait two minutes, and verify rearm before arming production behavior.

## Disable, recovery and rollback

Immediately disable future automatic reserve requests:

```sh
sudo systemctl disable --now battery-reserve.timer
sudo systemctl stop battery-reserve.service
```

Stopping cannot retract a sleep already requested. To pause without removing
the timer, set `armed = false` with `sudoedit /etc/battery-reserve.conf`.
To recover from a latched failure, preferably restore AC for two minutes.
If explicitly rearming on battery, disable the timer first, inspect logs,
then remove `/var/lib/battery-reserve/state.json` and reenable the timer only
when safe: at/below reserve this allows another suspend after debounce.

Restore all original files, unit enablement, and the original wake flags:

```sh
sudo /usr/bin/python3 /home/oji/workspace/self/dotfiles/bootstrap/linux/battery-reserve/install.py --rollback
```

Rollback reloads logind and restarts UPower; it does not restart GNOME or
change network/LUKS. The original backup and inert state directory remain
for inspection. Rollback restores the former battery lid behavior too.

Rollback removes the guard if it was absent when first backed up. If the guard
already existed (as after the 2026-10-24 live migration), rollback restores its
pre-package files and unit state instead. That independently installed guard
will remain active if it was active before package integration. An old backup
that has not been extended does not manage the separate guard. To explicitly
release the closed-lid inhibitor without rolling back the reserve policy:

```sh
sudo systemctl disable --now closed-lid-suspend-guard.service
```

The next non-skipped bootstrap enables it again. Stopping only the battery
timer, or setting `armed=false`, does not disable the guard. Stopping the guard
does not remove the logind lid-ignore drop-in or GNOME's existing inhibitors.

## Verification record, 2026-10-23

Before edits: AC=0, capacity=44% (later 41%), lid open, GNOME unlocked and
inhibitor PID 8538 active. Boot ID `5d3e3d1e-2b4f-480a-b171-81060225fc60`;
GNOME session 6, gnome-shell PID 6914, Ghostty PID 8120, T3 Code PID 7170.
`deep` is selected for suspend. Both macsmc wake flags already enabled;
ADP1 disabled. No legacy BCE suspend hooks found. Sudo needs authentication.

Nine isolated policy tests passed, including AC, above reserve, exact/below
reserve, debounce, unknown/missing/invalid telemetry, last-moment AC restore,
AC recheck errors, request failure, resume latch, AC bounce/stable rearm and
disarmed operation. Python syntax and staged systemd unit validation passed.
Live telemetry dry-run was read-only; no live sysfs test values were written.
Installation completed at 16:15 EEST. Timer and wake service are enabled;
the first timer check succeeded with AC=0 and capacity=39%. Configuration is
still disarmed. All three wake controls now read enabled, including ADP1;
logind's live HandleLidSwitch property reads ignore.

Controlled test: deep/S3 suspend entered at 16:22:17 EEST and completed resume
at 16:23:47 (90 seconds entry-to-exit, including preparation/resume overhead;
not a measurement of time spent fully asleep). Kernel counters report one
successful suspend and zero failures. The user reports charger restoration
woke it with the lid kept closed, followed by T3 reconnecting. Thus closed-lid
AC wake worked in this test; no exact firmware wake IRQ was exposed by the
inspection, and reliability over repeated/long outages is not established.

At 16:23:46 the first resumed timer poll saw AC=0, battery=35%, and correctly
reported `latched-until-stable-ac`. At 16:24:17 and subsequent polls AC=1;
capacity reached 37% by 16:26:21. The user briefly connected/disconnected/
reconnected the charger. Thirty-second policy samples do not capture every
transition, and the journal did not expose a complete adapter-edge timeline.
There was no second suspend. The same boot ID, GNOME session 6, and original
GNOME/Ghostty/T3/inhibitor PIDs all survived. GNOME GetActive=true and logind
LockedHint=yes; the existing sleep inhibitor is still held. Wi-Fi connection
`p` reactivated at 16:23:51, about four seconds after resume; SSH service and
socket are active and the local SSH transport responds. External LAN SSH
authentication and user interaction with other apps have not been separately
tested; T3's working remote connection is confirmed by the user.

Resume warnings: both external xHCI controllers logged USBSTS 0x401 and
reinitialized; `appletbdrm_primary_plane_reset` in the Touch Bar DRM driver
raised a kernel WARNING; brcmfmac reported errors recreating the Wi-Fi Direct
P2P interface. Normal Wi-Fi recovered despite those errors. t2bce core/VHCI
stateful resume returned status=0 and its audio deferred resume completed.
No failed systemd units or further warning-level kernel events were observed
after 16:24 during the immediate follow-up. Touch Bar/peripheral operation
needs user checking; these warnings are not described as a clean resume.

The initial helper run cancelled before suspension because it did not verify
the asynchronous screen lock in time. The helper now waits up to 15 seconds
for GetActive=true, avoids redundant Lock calls, and uses system gdbus on the
user's explicit session bus. No service reinstall was required for this fix.

Production arming completed after the controlled test. Live verification at
16:30 EEST showed `armed=True`, threshold=20, AC=1 and capacity=40%; the timer
and wake service are enabled. For future installations, arm locally with:

```sh
sudo sed -i 's/^armed = false$/armed = true/' /etc/battery-reserve.conf
/usr/local/libexec/battery-reserve --dry-run
```

No restart/reinstallation is needed. This change allows future low-battery
automatic suspension; it is safe to arm while the verified AC supply is online.

Run the isolated tests with `/usr/bin/python3 -B -m unittest discover -v`
from this directory. Current T2 guidance says t2bce handles its own suspend
and resume; never force-unload it. Suspend remains model-dependent:
[postinstall](https://wiki.t2linux.org/guides/postinstall/),
[device state](https://wiki.t2linux.org/state/).

## Closed-lid incident and migration, 2026-10-24

At 09:36:44 EET, logind's button dispatcher logged `Suspend key pressed short`
and initiated deep/S3 sleep. Resume completed at 12:03:46. The lid had been
closed since 2026-10-23 16:41; no thermal or battery trigger was identified.
The journal did not identify the input device. ACPI Sleep Button, the internal
keyboard, tiny-dfr virtual input and xremap all advertise `KEY_SLEEP`; none can
be named as the cause from this evidence.

On wake, the `mac-fan-daytime` watchdog expired and its guard was killed.
Manual override is now `N` and firmware fan control was restored. That
experiment is no longer running; it is not managed by this battery package.

The user ran the separate system-guard migration at 12:13:57 EET. The live
handoff verified at 12:14 that the root service was active with `NRestarts=0`
and the lid closed. Logind listed its root UID 0 block inhibitor for
`sleep:idle:handle-suspend-key:handle-hibernate-key`. The reserve timer and wake
service remained enabled and active. The read-only reserve check showed
`armed=True`, threshold 20, debounce 30 seconds, rearm 120 seconds, AC online
and battery 98%, with `decision=ac`. The former user guard was disabled and
inactive, and `Linger=no` was restored. Its unused user files remain installed.

Source integration copies the installed system script and unit exactly and
adds them to this package's installer, backup and rollback. Isolated parser,
inhibitor lifecycle and backup/rollback tests cover the source behavior.
The live migration and status above were reported by the implementation
thread; this source integration did not run an installer or suspend test.
No reboot, lid-cycle or actual sleep test has validated the new guard yet.
The 2026-10-23 charger-wake test predates the guard and was not repeated today.
