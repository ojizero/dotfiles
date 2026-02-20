---
paths:
  - "bootstrap/**"
---

Bootstrap script conventions:

- All scripts start with `#!/usr/bin/env zsh`
- Scripts must be idempotent — safe to run multiple times
- Use `rm -fr` before `ln -s` to handle pre-existing symlinks/files
- Numbered prefix determines execution order: `00`, `01`, `02`, ...
- The `.setup` extension is required
- Append `.once` for scripts that should only run once per machine (tracked via `bootstrap/.cache/`)
- Append `.disable` to prevent a `.once` script from running
- `$DOTFILES_PATH` is available in the environment
- Variable naming: `cfg_*` for repo path, `home_*` for home path
- `bootstrap/common/` runs on all platforms, `bootstrap/macos/` on macOS only
