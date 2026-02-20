---
paths:
  - "omz/**/*.zsh"
  - "m/**"
  - ".zshrc"
  - ".zprofile"
---

Shell script conventions:

- All shell code uses zsh
- Aliases use single quotes unless variable expansion is needed
- File suffix aliases use the `alias -s ext='cmd'` pattern
- Functions: use `function name {` or `name() {` consistently with surrounding code
- Environment exports: `export VAR="value"` with double quotes
- The `m` CLI commands use `case/esac` dispatch with a `usage` function and `help` subcommand
- Files in `omz/auto/` are auto-loaded via cat glob in `.zshrc`
- Module placement: aliases in `aliases.zsh`, env vars in `misc.zsh`, completions in `completions.zsh`
