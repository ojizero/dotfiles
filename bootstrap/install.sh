#! /bin/bash

# Canonical paths — keep in sync with .mise.toml [env] DOTFILES_PATH and [bootstrap.repos]
DOTFILES_CLONE_PATH=${DOTFILES_CLONE_PATH:-~/workspace/self}
DOTFILES_PATH=${DOTFILES_PATH:-${DOTFILES_CLONE_PATH}/dotfiles}

# Simply here as a workaround to allow HomeBrew installation to proceed while not being run as root.
# Ref: https://github.com/orgs/Homebrew/discussions/4311#discussioncomment-5240151
#
sudo echo

# Clone the dotfiles repository
#
mkdir -p "${DOTFILES_CLONE_PATH}"
git clone ssh://git@ssh-forge.ojizero.dev/ojizero/dotfiles.git "${DOTFILES_PATH}"

cd "${DOTFILES_PATH}"

# Install Homebrew if missing
export NONINTERACTIVE=1
if ! command -v brew >/dev/null 2>&1; then
  /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

case "$(uname -m)" in
  arm64)
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ;;
  x86_64)
    eval "$(/usr/local/bin/brew shellenv)"
    ;;
esac

# Install mise via Homebrew (minimal bootstrap dependency)
if ! command -v mise >/dev/null 2>&1; then
  brew install mise
fi

# Point mise at repo config before symlinks exist
export MISE_CONFIG_FILE="${DOTFILES_PATH}/.mise.toml"
mise trust "${DOTFILES_PATH}/.mise.toml"

# Seed local config if first run
[[ -f .mise.local.toml ]] || cp .mise.local.toml.sample .mise.local.toml

# Single convergence command (symlinks, brew bundle, tools, macOS extras)
mise bootstrap --yes --force-dotfiles
