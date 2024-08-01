#!/usr/bin/env just --justfile

set quiet

import '.imports.justfile'

_default:
  just --list -f {{justfile()}}

# Update system packages/apps via Homebrew
[group('Homebrew')]
update:
  brew update && brew upgrade && brew upgrade --casks
alias up := update
alias upgrade := update
