---
paths:
  - "bootstrap/**"
  - "mise.toml"
  - "mise.*.toml"
  - "devices/**"
---

Bootstrap conventions (Mise):

- Machine setup is declared in `mise.toml` (every device), `mise.macos.toml` / `mise.linux.toml` (per OS) and machine modules: `[dotfiles]`, `[bootstrap.*]`, `[tasks.bootstrap]`
- Each device has `devices/<name>.toml` (`auto_env = true` loads the OS module, `env` lists machine modules), linked to `~/.config/mise/miserc.local.toml`
- Converge with `mise bootstrap --yes` or `m dotfiles:bootstrap`
- New devices: `bootstrap/install.sh` installs Homebrew + mise, links `devices/$DEVICE.toml` (default: short hostname), then runs `mise bootstrap --yes --force-dotfiles`
- Devices from before `devices/` and the undotted paths: `zsh "${DOTFILES_PATH}/mise/tasks/dotfiles/migrate-devices" [device]` once
- Existing devices: `m dotfiles:sync` after pull; avoid `--force-dotfiles` unless status shows conflicts
- `[bootstrap.hooks.pre-packages]` installs Homebrew only; it stays for day-to-day use and casks mise cannot install
- Homebrew packages are `brew:` / `brew-cask:` entries in `[bootstrap.packages]` (see `packages.md`); there is no Brewfile
- Do not enable `[bootstrap.mise_shell_activate]` — `.zshrc` already activates mise
- macOS extras (pmset, gatekeeper, softwareupdate, battery %, third-party tap casks) live in `bootstrap/macos/extras.setup`, wired via `mise.macos.toml`'s `[tasks.bootstrap]`
- Ubuntu workstation setup lives in machine modules (`mise.linux-desktop.toml`), selected per device in `devices/<name>.toml`
- Ubuntu extras (Flatpaks, Homebrew app casks, Docker group, xremap, GNOME shortcuts, power) live in `bootstrap/linux/extras.setup`, wired via the linux-desktop module's `[tasks.bootstrap]`
- The computer-use module (`mise.computer-use.toml`, agent desktop for AI agents) runs `bootstrap/linux/computer-use.setup` from a `[bootstrap.hooks.final]` task, because a second `[tasks.bootstrap]` would replace linux-desktop's
- One-time gatekeeper approval tracked in `bootstrap/.cache/` (git-ignored)
- `$DOTFILES_PATH` is `~/workspace/self/dotfiles` — set in `mise.toml` `[env]`, `.zshrc`, and `[bootstrap.repos]`
- Bootstrap hooks and tasks must be idempotent
