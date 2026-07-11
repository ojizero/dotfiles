---
paths:
  - "bootstrap/**"
  - "mise.toml"
---

Bootstrap conventions (Mise):

- Machine setup is declared in `mise.toml`: `[dotfiles]`, `[bootstrap.*]`, `[tasks.bootstrap]`
- Converge with `mise bootstrap --yes` or `m dotfiles:bootstrap`
- New devices: `bootstrap/install.sh` installs Homebrew + mise, then runs `mise bootstrap --yes --force-dotfiles`
- Existing devices: `m dotfiles:sync` after pull; avoid `--force-dotfiles` unless status shows conflicts
- `[bootstrap.hooks.pre-packages]` installs Homebrew only (no symlinks or bundle)
- `brew bundle` runs in `[bootstrap.hooks.post-dotfiles]` after `~/.Brewfile` symlink exists; `dotfiles:bundle` trusts Brewfile taps inline before installing
- Do not enable `[bootstrap.mise_shell_activate]` — `.zshrc` already activates mise
- macOS extras (pmset, gatekeeper, softwareupdate, battery %) live in `bootstrap/macos/extras.setup`, wired via `[tasks.bootstrap]`
- One-time gatekeeper approval tracked in `bootstrap/.cache/` (git-ignored)
- `$DOTFILES_PATH` is `~/workspace/self/dotfiles` — set in `mise.toml` `[env]`, `.zshrc`, and `[bootstrap.repos]`
- Bootstrap hooks and tasks must be idempotent
