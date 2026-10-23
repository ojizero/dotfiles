# dotfiles

> Here be dragons 🐉

My personal dotfiles, including my system setup and the recipes and aliases I
use day to day. macOS is the primary workstation target. Ubuntu containers can
use the same Zsh, Git, agent, and mise setup without installing Homebrew.

## Setup

### New device

Run [`bootstrap/install.sh`](./bootstrap/install.sh). It will:

1. Clone this repo from Forgejo to `~/workspace/self/dotfiles` using the existing SSH setup
2. Install Homebrew (if missing) and `brew install mise`
3. Run `mise bootstrap --yes --force-dotfiles` (symlinks, Brewfile, tools, macOS defaults, extras)

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
