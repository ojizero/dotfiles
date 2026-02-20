---
name: symlink-audit
description: Audit all dotfile symlinks — verify they exist and point to correct targets. Use when checking dotfiles health.
context: fork
agent: Explore
---

# Symlink Audit

Parse all bootstrap scripts in `bootstrap/common/` to extract expected symlinks, then verify each one exists and points to the correct target.

## Expected Symlinks

From the bootstrap scripts, these symlinks should exist:

| Target in $HOME | Source in repo | Bootstrap script |
|-----------------|----------------|------------------|
| `~/.local` | `.local` | `bootstrap/common/00-local.setup` |
| `~/.brew-aliases` | `.brew-aliases` | `bootstrap/common/01-homebrew.setup` |
| `~/.Brewfile` | `Brewfile` | `bootstrap/common/01-homebrew.setup` |
| `~/.zshrc` | `.zshrc` | `bootstrap/common/02-zsh.setup` |
| `~/.zprofile` | `.zprofile` | `bootstrap/common/02-zsh.setup` |
| `~/.gitconfig` | `.gitconfig` | `bootstrap/common/03-git.setup` |
| `~/.asdfrc` | `.asdfrc` | `bootstrap/common/04-asdf.setup` |
| `~/.tool-versions` | `.tool-versions` | `bootstrap/common/04-asdf.setup` |

## Verification Steps

For each expected symlink:
1. Check if the path exists at all
2. Check if it is a symlink (not a regular file)
3. Check if it points to the correct target in the dotfiles repo
4. Report: OK, MISSING, NOT_A_SYMLINK, or WRONG_TARGET

## Output

Produce a summary table showing the status of each symlink. Flag any issues found.
