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

## Usage

### Local configurations

Anything living under [`.local`](./.local) folder is ignored from git. This folder is intended
for storing anything system specific that isn't from the dotfiles repo.

Currently the only special thing there is the the system specific Git configurations, which
are included as `~/.local.gitconfig` in the main `.gitconfig` file. During the dotfiles
setup a symlink is generate pointing the `~/.local.gitconfig` to `./.local/.gitconfig`
which can later be added by the user with system specific configurations.
