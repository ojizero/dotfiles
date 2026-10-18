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
`MISE_ENV=linux-desktop bootstrap/install.sh`. The choice is saved to the repo's
git-ignored `.miserc.local.toml`, linked to `~/.config/mise/miserc.local.toml`, for later runs.

### Machine modules (Ubuntu)

The base config works on macOS, Ubuntu workstations, and root containers. Extra
machine setup lives in modules, loaded only where `~/.config/mise/miserc.local.toml`
lists them (`env = ["linux-desktop"]`):

| Module | Covers |
|--------|--------|
| [`linux-desktop`](./.mise.linux-desktop.toml) | Tailscale, Cursor, Helium (apt), Zen, Obsidian, Smile (Flatpak), automatic light/dark mode (Night Theme Switcher), T3 Code (pinned so it updates itself), Docker (apt), Mac-style keyboard (xremap + GNOME shortcuts + Mac layouts), lid and sleep policy, via [`bootstrap/linux/extras.setup`](./bootstrap/linux/extras.setup) |

The keyboard service pins the internal keyboard by its `/dev/input/by-path` name in
[`xremap/mac-keyboard.service`](./xremap/mac-keyboard.service); adjust it for another
machine, and never select it by device name (the trackpad shares it).

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
