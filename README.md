# dotfiles

> Here be dragons 🐉

My personal dotfiles, including my system setup and the recipes and aliases I
use day to day. macOS is the primary workstation target, Ubuntu workstations use Homebrew
for the same CLI tools. Ubuntu containers (running as root) can use the same
Zsh, Git, agent, and mise setup without installing Homebrew.

## Setup

### New device

Run [`bootstrap/install.sh`](./bootstrap/install.sh). It will:

1. Clone this repo from Forgejo to `~/workspace/self/dotfiles` using the existing SSH setup
2. Install Homebrew (if missing) and `brew install mise`
3. Run `mise bootstrap --yes --force-dotfiles` (system packages, symlinks, Brewfile, tools, login shell, macOS defaults, extras)

On an Ubuntu workstation, pick its machine modules when running it, for example
`MISE_ENV=linux-desktop bootstrap/install.sh` (or `MISE_ENV=linux-desktop,computer-use`). The choice is saved to the repo's
git-ignored `.miserc.local.toml`, linked to `~/.config/mise/miserc.local.toml`, for later runs.

### Machine modules (Ubuntu)

The base config works on macOS, Ubuntu workstations, and root containers. Extra
machine setup lives in modules, loaded only where `~/.config/mise/miserc.local.toml`
lists them (`env = ["linux-desktop"]`):

| Module | Covers |
|--------|--------|
| [`linux-desktop`](./.mise.linux-desktop.toml) | Tailscale, Cursor, Helium (apt), Zen, Obsidian, Smile, Secrets, KeePassXC (Flatpak), automatic light/dark mode (Night Theme Switcher), T3 Code (pinned so it updates itself), Docker (apt), Mac-style keyboard (xremap + GNOME shortcuts + Mac layouts), lid and sleep policy, via [`bootstrap/linux/extras.setup`](./bootstrap/linux/extras.setup) |
| [`computer-use`](./.mise.computer-use.toml) | An agent desktop for AI agents next to GNOME: headless Sway, VNC on localhost, the Cua Driver daemon and its MCP server for Claude Code and Codex, agent-only Zen and Helium profiles, via [`agent-desktop/`](./agent-desktop) and [`bootstrap/linux/computer-use.setup`](./bootstrap/linux/computer-use.setup). Needs `linux-desktop` (`env = ["linux-desktop", "computer-use"]`) |

Machine-specific values in the `linux-desktop` module, to adjust for another machine or place:

- **Keyboard device.** The keyboard service pins the internal keyboard by its
  `/dev/input/by-path` name in [`xremap/mac-keyboard.service`](./xremap/mac-keyboard.service).
  Never select it by device name (the trackpad shares it).
- **Location.** GNOME needs a location for sunrise and sunset (Night Theme Switcher's light/dark
  switching and Night Light). Macs have no GPS, and the Wi-Fi lookup (beaconDB) may find no
  match; its IP-based guess is too coarse for GNOME. Give geoclue a fixed location in a
  git-ignored `.geolocation.local` at the repo root, four lines: latitude, longitude, altitude
  and accuracy in metres (`#` comments allowed). The extras install it as `/etc/geolocation`.
- **Docker.** Docker Engine comes from Docker's apt repository as a system service, and
  the extras add you to the `docker` group, so `docker` works without `sudo` after the next login.
- **Updates that bypass Homebrew.** xremap is a mise tool from the module (update it with
  `mise up -C ~/workspace/self/dotfiles`; the keyboard service runs mise's `latest`).
  GNOME Shell updates the xremap and Night Theme Switcher extensions. T3 Code updates
  itself; its cask is pinned so `brew upgrade` leaves it alone.

Sagittarius A* has an opt-in [local battery reserve policy](./bootstrap/linux/battery-reserve/README.md)
for closed-lid server use: suspend at 20% on battery, preserving the GNOME session.
Its root lid guard blocks ordinary sleep and sleep-key handling while closed;
the reserve policy keeps its explicit inhibitor bypass. Opening releases the guard.
The Linux desktop bootstrap maintains an existing installation; opt in on a fresh
MacBookPro16,1 with `DOTFILES_BATTERY_RESERVE=1` (or explicitly skip with `0`).
Its reviewed installer, configuration, measured hardware test and rollback live there.

The same hardware can opt in to the [Quiet fan adapter](./bootstrap/linux/mac-quiet-fans/README.md)
with `DOTFILES_MAC_QUIET_FANS=1`. It adapts neofand's selected Quiet curve to
`macsmc_hwmon`; it is separate from the battery policy. Default bootstrap only
maintains an already enabled installation. Its live installation is verified;
reboot and suspend behavior remain untested.

#### Password managers (Linux desktop)

The desktop extras install GNOME Secrets and KeePassXC as user Flatpaks from
Flathub, the Linux install method recommended by both upstream projects.
Open Secrets from the app launcher or run `flatpak run --user org.gnome.World.Secrets`.
Secrets does not support passkey authentication.

The whole KeePassXC app is installed to get its official bundled `keepassxc-cli`.
The Linux desktop extras copy [the shell launcher](./bootstrap/linux/bin/keepassxc-cli)
into `~/.local/bin/keepassxc-cli`; run `keepassxc-cli --help` to see its commands.
This is not the third-party Python `kpxc-cli`. macOS keeps its native CLI.
Both apps update through the existing `m update:all` Flatpak step.

#### Sagittarius A*: network and LUKS remote unlock

Host `sagittarius-a` runs Ubuntu 26.04.1 with T2 kernel `7.3.0-3-t2-resolute`
as of 2026-10-23. Its root filesystem is inside LUKS; `/boot` is separate and
unencrypted. The configuration below lives on the host. The dotfiles bootstrap
does not provision it.

**Network configuration.** Normal Ubuntu uses NetworkManager with Netplan
integration. Wi-Fi profile `p` (UUID `746ba88f-c43b-4285-9a6c-70f1984ee477`)
uses interface `wlp5s0`, autoconnect, and persistent manual IPv4 settings.
Read the saved profile and its Netplan sources for the current address, gateway,
and DNS; do not assume DHCP.

Early boot has a separate address source:
`/etc/systemd/network/20-initrd-unlock.network` (mode `0644`). It configures
`wlp5s0` with static IPv4, gateway, and DNS, with `DHCP=no`,
`IPv6AcceptRA=no`, and `LinkLocalAddressing=no`. Keep these values consistent
with the normal Wi-Fi profile. There is no shared configuration source yet.
When the address changes, update both sources and rebuild the applicable
initramfs images. Use `<unlock-ip>` below for the address in the early network
configuration; the deployment address is not a fixed property of this host.

**Before disk unlock.** Dracut starts Wi-Fi and OpenSSH before LUKS unlock.
Root SSH listens on port `2222`, accepts public keys only, and forces
`/usr/bin/systemd-tty-ask-password-agent --query`. Forwarding is disabled.
Replace `<unlock-ip>` with that configured address and connect with an authorized key:

```bash
ssh -p 2222 'root@<unlock-ip>'
```

Enter the disk passphrase at the forced prompt. Normal SSH and Tailscale are
separate services that run after unlock. Tailscale has not been verified as a
pre-unlock transport. This setup uses Dracut and OpenSSH, not
`dropbear-initramfs`.

Persistent Dracut configuration is `/etc/dracut.conf.d/90-remote-unlock.conf`.
The modules are `46sshd`, `/usr/lib/dracut/modules.d/47unlock-wifi`, and
`/usr/lib/dracut/modules.d/99zzunlock-sanitize`. Wi-Fi settings are in
`/etc/dracut-sshd/initrd-wifi.conf` (mode `0600`), and its service source is
`/etc/dracut-sshd/initrd-wifi.service` (mode `0644`). The Wi-Fi credential must
be in the unencrypted boot image so Wi-Fi can connect before encrypted root is
available. Do not copy the credential into this repo or logs.

**Repair completed on 2026-10-23.** The early Wi-Fi settings still selected an
old network. The early network file had mode `0600`, which caused
systemd-networkd to report `Permission denied`. The repair selected SSID `p`
with its saved credential, set the early static network values to match the
normal profile, and corrected the network and Wi-Fi service file permissions.
Normal Ubuntu's saved manual IPv4 configuration, active address, route, and SSH
access were verified. SSH policy, authorized keys, disk credentials, and LUKS
slots did not change.

Both `/boot/initrd.img-7.2.11-3-t2-resolute` and
`/boot/initrd.img-7.3.0-3-t2-resolute` were rebuilt. Each candidate was unpacked
and checked before atomic replacement. Checks passed for Wi-Fi and static
network settings, networkd-readable files, private credential permissions,
unchanged SSH policy and keys, enabled SSH/Wi-Fi/networkd units, required
executables and Broadcom firmware, sanitized account password fields, crypttab
without a key file, and SSH daemon syntax. The generic fallback image was not
modified.

Root-only backups of the source configuration and original T2 images are in
`/var/backups/remote-unlock-20261023T121516Z`. Host-local evidence is in
`/home/oji/audit-remote-unlock.py` and `/home/oji/audit-remote-unlock.log`, plus
`/home/oji/repair-remote-unlock.py` and `/home/oji/repair-remote-unlock.log`.
The repair log ends in `SUCCESS`; no repair processes or temporary candidate
images remained. The repair helper contains one-time deployment settings. It
is not a configurable provisioning tool.

**Reboot test pending.** Image checks passed, but no reboot was performed after
the repair. End-to-end remote unlock is not yet proven. Keep a local-unlock
recovery path available, then check:

1. Check the router's DHCP exclusion or reservation for the configured static
   address. This was not configured or verified. A ping/neighbor probe found no
   responding host at that address at the time; it does not prevent a later
   address conflict.
2. Reboot and verify early Wi-Fi association and public-key SSH authentication
   on port `2222` at `<unlock-ip>`.
3. Enter the LUKS passphrase through the forced prompt and verify the transition
   to normal Ubuntu, including normal SSH and the saved network configuration.

#### The computer-use module

AI agents keep running in GNOME (for example in T3 Code). They drive apps in a second
desktop, a headless Sway that only they use, through the [Cua Driver](https://cua.ai/docs/cua-driver).
GNOME stays your desktop, and its screen can stay locked. Four systemd user services run it
while your user manager runs (that is, while you are logged in to GNOME):

| Service | Runs |
|---------|------|
| `agent-desktop` | Headless Sway, 1920x1080, no XWayland, software rendering ([`sway.conf`](./agent-desktop/sway.conf)) |
| `agent-desktop-bus` | A private D-Bus session bus for everything in the agent desktop |
| `agent-desktop-vnc` | wayvnc on `127.0.0.1:5900` |
| `agent-desktop-cua` | `cua-driver serve` on `$XDG_RUNTIME_DIR/agent-desktop/cua-driver.sock` |

`systemctl --user restart agent-desktop` restarts all four; `stop` and `start` work the same way.

- **Connect an agent.** Agents use the daemon's socket:
  `cua-driver mcp --socket /run/user/$UID/agent-desktop/cua-driver.sock`. The setup registers this
  MCP server as `cua-driver` for Claude Code (user scope) and Codex. Do not use a bare
  `cua-driver mcp`: on Linux it starts its own runtime in the agent's environment, which is GNOME.
- **Watch it, or sign in to sites.** Tunnel VNC over SSH or Tailscale, then open a VNC viewer on
  `localhost:5900`: `ssh -L 5900:localhost:5900 <this machine>`.
- **Run an app in the agent desktop yourself.**
  `~/.config/agent-desktop/run <command>` runs a command with the agent desktop's environment.
- **Clean environment.** [`agent-desktop/run`](./agent-desktop/run) starts every service from an
  empty environment, so nothing leaks in from GNOME or T3 Code (`DISPLAY`, GNOME's bus,
  `ELECTRON_RUN_AS_NODE`). It gives the services the Sway display, the private bus, their own
  runtime directory (`$XDG_RUNTIME_DIR/agent-desktop/runtime`) and agent-only XDG folders in
  `~/.agent-desktop`. On GNOME's bus the driver's accessibility signal would start Orca, and in the
  shared runtime directory the agent desktop's document portal, gvfs and keyring would collide with
  GNOME's. Never import the agent desktop's variables into the user manager
  (`systemctl --user import-environment`): GNOME shares it.
- **Separate profiles.** Native apps get their own profiles from the agent XDG folders, so one copy
  can run in each desktop at the same time. dconf and the keyring are separate too. Flatpak apps
  ignore these folders, so the agent desktop has launchers first on its `PATH`, plus matching
  desktop entries: `zen` opens the profile `~/.var/app/app.zen_browser.zen/agent-desktop`, and
  `helium` opens `~/.agent-desktop/config/net.imput.helium` and keeps passwords in the profile.
  Your GNOME profiles stay untouched.
- **Flatpak apps and accessibility.** AT-SPI knows a Flatpak app (Zen) by the pid of its
  `xdg-dbus-proxy`, not the pid that owns its window. Pass the proxy's pid (from `list_apps`) with
  the window's `window_id` to `get_window_state` and element actions, and the window's own pid to
  typing and keys (`delivery_mode: "foreground"`).
- **Recordings.** Over one MCP connection, `start_recording` with `record_video: true` writes an
  H.264 `recording.mp4` and per-step evidence; `cua-driver recording render <dir> <out.mp4>` makes a
  zoom-on-click video. Recording stops when the MCP client disconnects.
- **Updates.** The apt packages update with the system. The Cua Driver has no apt package or Homebrew
  formula: the setup installs it once into `~/.cua-driver` (`~/.local/bin/cua-driver`), and
  `cua-driver update --apply` updates it (`cua-driver check-update` checks; every release is marked
  pre-release on GitHub, and releases come often). The daemon service restarts on the new version.
  Telemetry is off (`cua-driver telemetry disable`).
- **Not covered yet.** Snap apps (Firefox, Thunderbird) only start on a private bus inside a systemd
  scope named `snap.<snap>.<app>-<uuid>`, so they do not run in the agent desktop. Sway uses software
  rendering, because the GPU render node is only granted to the active seat. After a reboot nothing
  starts until you log in to GNOME: the disk is encrypted and auto-login and linger are off.

### Existing device

After pulling changes, converge with:

```bash
m dotfiles:sync
```

Or step through the migration runbook:

```bash
m dotfiles:pull
mise bootstrap dotfiles apply --dry-run
mise bootstrap dotfiles apply --yes
mise bootstrap --skip repos --yes
m dotfiles:status
```

Do not use `--force-dotfiles` on existing machines unless `mise bootstrap dotfiles status` reports conflicts.

### Fresh VM test (manual)

On a clean macOS VM:

1. Install Xcode CLI tools: `xcode-select --install`
2. Verify SSH access to Forgejo and GitHub, then run `bootstrap/install.sh`
3. Open a new shell and verify:
   - `echo $DOTFILES_PATH` → `~/workspace/self/dotfiles`
   - `m dotfiles:status` exits 0
   - `mise doctor` — no config conflicts
   - Spot-check: `m dns:list`, `ls -la ~/.zshrc` (symlink into repo)

## Usage

### Repo path

All personal repos live under `~/workspace/`. Dotfiles are cloned to:

```
~/workspace/self/dotfiles
```

This path is declared in `.mise.toml` as `[env].DOTFILES_PATH` and `[bootstrap.repos]`, exported in `.zshrc`, and used by `bootstrap/install.sh`.

### Local configurations

Anything living under [`.local`](./.local) folder is ignored from git. This folder is intended
for storing anything system specific that isn't from the dotfiles repo.

Currently the only special thing there is the system specific Git configurations, which
are included as `~/.local/.gitconfig` in the main `.gitconfig` file. During bootstrap
a symlink is created pointing `~/.local` to `./.local`, and you can add
`./.local/.gitconfig` with machine-specific Git settings.

Per-machine mise overrides live in `.mise.local.toml` (git-ignored). Copy from
`.mise.local.toml.sample` or let bootstrap seed it on first run.

Codex execution-policy rules live under [`.codex/rules`](./.codex/rules).
Mise links them into `~/.codex/rules` without replacing Codex's machine-local
configuration, credentials, plugins, or runtime state.

### Dotfiles tasks

| Task | Description |
|------|-------------|
| `m dotfiles:pull` | Pull latest changes |
| `m dotfiles:sync` | Pull + apply dotfiles + install tools + bundle if Brewfile changed |
| `m dotfiles:status` | Show bootstrap and dotfiles drift |
| `m dotfiles:bootstrap` | Full `mise bootstrap --yes` |
| `m dotfiles:bundle` | Install Homebrew packages from Brewfile |
| `m dotfiles:edit` | Open dotfiles repo in `$EDITOR` |

`m dns:*` and `m update:*` work on both macOS and Ubuntu (systemd-resolved; apt, snap, Flatpak and firmware).

### Remote Linux unlock

```sh
mise linux:unlock sagittarius-a
```

Uses the SSH alias `<device>-unlock` for the interactive LUKS passphrase prompt,
then waits for normal SSH through `<device>`. If neither endpoint is ready yet,
it retries within the timeout. A closed unlock connection does not count as
success; only a working normal SSH connection advances to desktop startup.
Hosts, addresses, ports and keys
belong in `~/.ssh/config`; this task has no device IPs. Normal SSH probes use
batch mode, so load passphrase-protected login keys into your SSH agent first.
Use `--timeout 300` to change the default 180-second connection retry window.
An already-unlocked host skips the LUKS step. An existing GNOME session is reused,
and the task avoids starting another inhibitor if its own is already running.

The remote host must run Linux with GDM/GNOME, Ghostty, Python 3 and
`gnome-session-inhibit`. Its account must have sudo access. From GDM's login
screen, the task temporarily enables automatic login for the SSH user, restarts
GDM, and restores the previous runtime configuration after GNOME starts. It
leaves existing desktops on seat0 untouched and does not enable permanent
automatic login. Select GNOME as that user's normal GDM session beforehand.

The task installs a GNOME-only autostart entry that opens Ghostty with idle and
suspend inhibited, then locks the screen. Other autostart apps continue starting
behind the lock. It verifies both inhibitors and the screen lock before returning;
closing the Ghostty window releases the inhibitors. There is a brief unlocked
desktop during startup. Automatic login does not unlock the login keyring, so
apps using saved credentials may still need its password. Headless Sway is not
part of this flow. If desktop startup fails, the temporary GDM override is restored;
the task does not reboot or change LUKS credentials.

Remove `~/.config/autostart/gnome-inhibit-and-lock.desktop` on the remote host
to disable the inhibitor and screen-lock behavior on future GNOME logins.

### Housekeeping

Disk cleanup for macOS, as global mise tasks in [`.mise/tasks/housekeeping`](./.mise/tasks/housekeeping).
Reports and history go to `~/.local/state/housekeeping/`.

| Task | Description |
|------|-------------|
| `m housekeeping` | Clean caches, merged worktrees and old build output, then write an HTML report (`--dry-run` to preview) |
| `m housekeeping:periodic` | Run it weekly through launchd, Saturdays 03:00 by default (`--day`, `--at`, `--remove`) |
| `m housekeeping:status` | Show the schedule, a run in progress, and the last run |
| `m housekeeping:disk` | Show disk and memory health and where the space goes; removes nothing |

The `housekeeping` agent skill next to them is linked into `~/.agents/skills`, so agents in any
project can check on it and diagnose disk space.
