---
paths:
  - "mise.toml"
  - "mise.*.toml"
  - "bootstrap/**/extras.setup"
---

Package conventions (`[bootstrap.packages]`):

- Homebrew packages are mise entries: `"brew:<formula>" = "latest"`, `"brew-cask:<cask>" = "latest"`
- Every device: `mise.toml`. macOS only: `mise.macos.toml`. Linux system packages (`apt:`): `mise.linux.toml` or a machine module
- Entries are alphabetically sorted within each commented group
- mise installs casks only on macOS (fonts also on Linux): Linux app casks are installed with `brew install --cask` in `bootstrap/linux/extras.setup`
- Third-party tap casks get no Homebrew metadata from mise: install them with `brew` in the OS extras
- No Mac App Store (`mas:`) entries
- Machine-specific packages go in `mise.local.toml` (git-ignored), never in the tracked configs
