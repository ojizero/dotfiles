#!/usr/bin/env just --justfile

set quiet

import '.imports.justfile'

_default:
  just --list -f {{justfile()}}
