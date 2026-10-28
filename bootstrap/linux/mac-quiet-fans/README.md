# MacBookPro16,1 Quiet fan adapter

This package persists the selected neofand Quiet policy on Sagittarius A*,
MacBookPro16,1, Ubuntu 26.04.1 with the T2 kernel and `macsmc_hwmon`.
It is a local Python adapter, not an installed neofand build or a t2linux
shipped default. Upstream neofand expects `*_manual`/`*_output`; this machine
exposes `fan*_target`. The controller, service and sleep hook are the exact
sources prepared by the thermal thread and installed on 2026-10-24.

## Selected policy

Curve provenance: `akhilv1/neofand` commit
`9da402c87a6a3941047ec08bf71d2120076eec82`, `src/config.rs` and
`src/fan_controller.rs`. No delayed or aggressive alternative was selected.

- CPU package range: 70–92 °C. AMD GPU junction range: 80–96 °C.
- Normalize each temperature over its range and clamp to 0–1. The larger
  normalized demand, cubed, maps each fan's hardware minimum to maximum RPM.
- Read whole Celsius values. Increase immediately; on falling temperatures,
  use the larger of the current value and the trailing 20-sample integer mean.
- Poll once per second. Discover sensors by labels and fan limits from sysfs;
  this host reports 1836–5616 RPM and 1700–5200 RPM.

The owner marker `/run/mac-quiet-fans/owned` identifies this service's override.
The controller refuses an existing unowned override. Exit and `ExecStopPost`
release owned targets to 0 and then set `fan_control=N`. If a target release
fails, it attempts maximum RPM for that fan, records `RESTORE_FAILED`, retains
ownership and reports failure rather than claiming firmware restoration.
The service restarts on failure and has a 30-second watchdog.

## Bootstrap and installation

The `linux-desktop` extras call this package's `bootstrap.sh`.
`DOTFILES_MAC_QUIET_FANS=1` explicitly installs and starts it on a fresh
MacBookPro16,1. Value `0` skips it. Unset/`auto` maintains only an installed,
enabled service; it does not reenable a disabled controller. The optional
per-machine setting is shown in `mise.local.toml.sample`.

Manual installation from the dotfiles checkout:

```sh
sudo bash bootstrap/linux/mac-quiet-fans/install-quiet-fans.sh
```

This is an active fan-control installation, with no observation-only stage.
The installer checks the hardware model, performs a read-only sensor check,
and refuses active `mac-fan-overnight`, `mac-fan-daytime`, neofand, t2fanrd,
mbpfan, macfanctld or fancontrol services. It shares the prepared fan-setup
lock and refuses an unrecognized manual override. It does not stop competing
daemons or change the chosen curve.

Root-owned installed files:

| Source | Installed path | Mode |
|--------|----------------|------|
| `mac-quiet-fans.py` | `/usr/local/lib/mac-quiet-fans/controller.py` | 0755 |
| `mac-quiet-fans.service` | `/etc/systemd/system/mac-quiet-fans.service` | 0644 |
| `mac-quiet-fans-sleep` | `/usr/lib/systemd/system-sleep/mac-quiet-fans` | 0755 |

The service is enabled under `multi-user.target`. Before sleep, the hook
records whether it was active, stops it and releases manual fan control.
After resume it starts the service only if it was active before sleep and
is still enabled. This hook does not request sleep or change the battery
reserve, closed-lid guard, GNOME, network, LUKS or boot images.

Read-only status checks:

```sh
systemctl status mac-quiet-fans.service
cat /run/mac-quiet-fans/status.json
journalctl -u mac-quiet-fans.service -n 30
/usr/bin/python3 bootstrap/linux/mac-quiet-fans/mac-quiet-fans.py --check
```

## Disable and rollback

Stop this controller and release its owned override to firmware control:

```sh
sudo systemctl disable --now mac-quiet-fans.service
```

Check the service journal, `status.json` and
`/sys/module/macsmc_hwmon/parameters/fan_control` for successful release (`N`).
A release error requires investigation; do not assume firmware owns the fans.
Default bootstrap skips a disabled service. Explicit opt-in with value `1`
starts it again; value `0` skips all package maintenance.

The packaged installer saves original files, modes and enabled/active service
state once in `/var/backups/mac-quiet-fans-original` (root-only). Repeat
installs preserve this backup. Restore it with:

```sh
sudo bash bootstrap/linux/mac-quiet-fans/install-quiet-fans.sh --rollback
```

Rollback stops and disables the current service, requires the manual override
to be released, and restores the prior files and unit state. Files absent at
backup time are removed. If the thermal thread's Quiet installation already
existed when first backed up, rollback restores that installation, including
its active/enabled state. Use the disable command above to return to firmware
control instead. The original backup and inert runtime/status files remain.

The thermal thread's original scratch installer did not create this package's
backup. Integration alone does not create one; it is created the next time
the packaged installer is explicitly run or maintained through bootstrap.

## Verification record

The fixed-RPM experiments finished at 21:00 on 2026-10-24; firmware override
`N` was verified before the selected Quiet installation. They are no longer
running.

The thermal thread reports that the user ran the prepared installer. At about
21:58:32 Gaza time on 2026-10-24, `mac-quiet-fans.service` was active/running,
enabled with its `multi-user.target.wants` symlink, and had `NRestarts=0` and
a 30-second watchdog. The journal showed a clean start at 21:58:03 with no
errors. Status was four seconds old and reported `quiet-automatic`.
CPU was 50 °C and GPU junction 49 °C; actual RPM was 1838/1699 against targets
1836/1700. Manual override `Y` was expected while the controller ran. All
three installed files matched the prepared sources byte-for-byte with the
root ownership and modes listed above. Persistence is configured.

Source integration preserves those three runtime files without changes.
Isolated tests cover the curve, response, full controller loop and release
failure in fake sysfs, plus relocated installer/rollback, bootstrap options
and sleep-hook decisions with stub service commands. No live installer,
fan writes, suspend or reboot ran during source integration.

Reboot and hardware suspend/resume behavior have not been exercised for this
controller. Unit/source validation and a configured boot symlink do not prove
those paths. The earlier battery charger-wake test predates this controller.

Run source tests from the checkout with:

```sh
/usr/bin/python3 -B -m unittest discover -v -s bootstrap/linux/mac-quiet-fans
```
