---
paths:
  - "bootstrap/**"
  - ".mise.toml"
---

Bootstrap conventions (Mise):

- Machine setup is declared in `.mise.toml`: `[dotfiles]`, `[bootstrap.*]`, `[tasks.bootstrap]`
- Converge with `mise bootstrap --yes` or `m dotfiles:bootstrap`
- New devices: `bootstrap/install.sh` installs Homebrew + mise, then runs `mise bootstrap --yes --force-dotfiles`
- Existing devices: `m dotfiles:sync` after pull; avoid `--force-dotfiles` unless status shows conflicts
- `[bootstrap.hooks.pre-packages]` installs Homebrew only (no symlinks or bundle)
- `[bootstrap.packages]` holds Linux-only apt packages (`os = "linux"`); CLI tools stay in the Brewfile
- `brew bundle` runs in `[bootstrap.hooks.post-dotfiles]` after `~/.Brewfile` symlink exists; `dotfiles:bundle` trusts Brewfile taps inline before installing
- Do not enable `[bootstrap.mise_shell_activate]` — `.zshrc` already activates mise
- macOS extras (pmset, gatekeeper, softwareupdate, battery %) live in `bootstrap/macos/extras.setup`, wired via `[tasks.bootstrap]`
- Ubuntu workstation setup lives in machine modules (`.mise.linux-desktop.toml`), selected per machine in `~/.config/mise/miserc.local.toml`; the base config must stay safe for root containers
- Ubuntu extras (Flatpaks, rootless Docker, xremap, GNOME shortcuts, power) live in `bootstrap/linux/extras.setup`, wired via the linux-desktop module's `[tasks.bootstrap]`
- One-time gatekeeper approval tracked in `bootstrap/.cache/` (git-ignored)
- `$DOTFILES_PATH` is `~/workspace/self/dotfiles` — set in `.mise.toml` `[env]`, `.zshrc`, and `[bootstrap.repos]`
- Bootstrap hooks and tasks must be idempotent
