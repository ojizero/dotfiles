---
paths:
  - "omz/**/*.zsh"
  - ".mise/tasks/**"
  - ".zshrc"
  - ".zprofile"
---

Shell script conventions:

- All shell code uses zsh
- Aliases use single quotes unless variable expansion is needed
- File suffix aliases use the `alias -s ext='cmd'` pattern
- Functions: use `function name {` or `name() {` consistently with surrounding code
- Environment exports: `export VAR="value"` with double quotes
- Mise tasks are standalone zsh scripts in `.mise/tasks/` with `#MISE` frontmatter comments
- Dotfiles tasks: `dotfiles:pull`, `dotfiles:sync`, `dotfiles:status`, `dotfiles:bootstrap`, `dotfiles:bundle`, `dotfiles:edit`
- Files in `omz/auto/` are auto-loaded via cat glob in `.zshrc`
- Module placement: aliases in `aliases.zsh`, env vars in `misc.zsh`, completions in `completions.zsh`
