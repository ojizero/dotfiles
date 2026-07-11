# Symlink Audit

Verify dotfile symlinks using Mise bootstrap status (preferred) or manual checks.

## Automated check

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles status --missing   # exit 1 if drift
m dotfiles:status                          # bootstrap + dotfiles status
```

## Expected symlinks

From `[dotfiles]` in `mise.toml`:

| Target in $HOME | Source in repo |
|-----------------|----------------|
| `~/.local` | `.local` |
| `~/.brew-aliases` | `.brew-aliases` |
| `~/.Brewfile` | `Brewfile` |
| `~/.zshrc` | `.zshrc` |
| `~/.zprofile` | `.zprofile` |
| `~/.gitconfig` | `.gitconfig` |
| `~/.bunfig.toml` | `bunfig.toml` |
| `~/.config/mise/config.toml` | `mise.toml` |
| `~/.config/mise/config.local.toml` | `mise.local.toml` |
| `~/.config/mise/tasks` | `.mise/tasks` |
| `~/.claude/settings.json` | `.claude/settings.json` |
| `~/.claude/statusline-command.sh` | `.claude/statusline-command.sh` |
| `~/.config/ghostty` | `ghostty` |
| `~/.config/nvim` | `nvim` |
| `~/.config/worktrunk` | `worktrunk` |

## Manual verification

For each expected symlink:
1. Check if the path exists
2. Check if it is a symlink (not a regular file)
3. Check if it points to the correct target in the dotfiles repo
4. Report: OK, MISSING, NOT_A_SYMLINK, or WRONG_TARGET

## Repair

```bash
mise bootstrap dotfiles apply --yes
# conflicts only:
mise bootstrap dotfiles apply --yes --force
# or full bootstrap:
mise bootstrap --yes --force-dotfiles
```

Produce a summary table showing the status of each symlink. Flag any issues found.
