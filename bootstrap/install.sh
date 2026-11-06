#! /bin/bash
set -e

# Keep these paths in sync with mise/config.toml [env] and mise.toml [bootstrap.repos].
DOTFILES_CLONE_PATH=${DOTFILES_CLONE_PATH:-~/workspace/self}
export DOTFILES_PATH=${DOTFILES_PATH:-${DOTFILES_CLONE_PATH}/dotfiles}

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

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ;;
  Darwin/x86_64)
    eval "$(/usr/local/bin/brew shellenv)"
    ;;
  Linux/*)
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    ;;
esac

# Install mise via Homebrew (minimal bootstrap dependency)
if ! command -v mise >/dev/null 2>&1; then
  brew install mise
fi

# Device file (devices/<name>.toml, default: the short hostname) picks the OS and machine
# modules; linked where mise reads it before any config, for later runs
DEVICE=${DEVICE:-$(hostname -s | tr '[:upper:]' '[:lower:]')}
if [[ ! -f "${DOTFILES_PATH}/devices/${DEVICE}.toml" ]]; then
  echo "No devices/${DEVICE}.toml: add one, or pick another with DEVICE=<name>" >&2
  exit 1
fi
mkdir -p ~/.config/mise
ln -sfn "${DOTFILES_PATH}/devices/${DEVICE}.toml" ~/.config/mise/miserc.toml

# Make the runtime config and global tasks available before bootstrap.
zsh "${DOTFILES_PATH}/mise/tasks/dotfiles/seed-local"
ln -sfn "${DOTFILES_PATH}/mise/config.toml" ~/.config/mise/config.toml
ln -sfn "${DOTFILES_PATH}/mise/config.local.toml" ~/.config/mise/config.local.toml
ln -sfn "${DOTFILES_PATH}/mise/tasks" ~/.config/mise/tasks
zsh "${DOTFILES_PATH}/mise/tasks/dotfiles/trust"

# Single convergence command (packages, symlinks, tools, macOS extras)
mise bootstrap --yes --force-dotfiles
