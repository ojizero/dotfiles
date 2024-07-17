#!/usr/bin/env just --justfile

# Install a system package or app via Homebrew
install +pkgs_or_opts:
  brew install {{pkgs_or_opts}}

# Update system packages/apps via Homebrew
update:
  brew update && brew upgrade && brew upgrade --casks

# Uninstall a system package or app via Homebrew
uninstall +pkgs_or_opts:
  brew uninstall --zap {{pkgs_or_opts}}

# Manage Homebrew taps
tap *taps_or_opts:
  brew tap {{taps_or_opts}}

alias i := install
alias up := update
alias upgrade := update
alias unin := uninstall
alias taps := tap
