# dotfiles

> Here be dragons 🐉

My personal dotfiles, those include my system setup along with a bunch of recipes,
scripts, and aliases I use day to day. Those were made and are only used with
Zsh on macOS, so no compatibility outside that environment is actively made.

## Setup

### Bootstrap script

There's a bootstrap script found in [`bootstrap/install.sh`](./bootstrap/install.sh)
that should, if run, pull this repo and set everything up.

### Manually

1. Pull the repo somewhere.
1. Install [Homebrew](https://brew.sh).
1. Install [just](https://just.systems) `brew install just`.
1. Run `just setup`.
