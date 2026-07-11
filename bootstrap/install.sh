#! /bin/bash

GITHUB_SSH_KEY=${GITHUB_SSH_KEY:-~/.ssh/github.self}
# Canonical paths — keep in sync with mise.toml [env] DOTFILES_PATH and [bootstrap.repos]
DOTFILES_CLONE_PATH=${DOTFILES_CLONE_PATH:-~/workspace/self}
DOTFILES_PATH=${DOTFILES_PATH:-${DOTFILES_CLONE_PATH}/dotfiles}

# Simply here as a workaround to allow HomeBrew installation to proceed while not being run as root.
# Ref: https://github.com/orgs/Homebrew/discussions/4311#discussioncomment-5240151
#
sudo echo

# Generate a new SSH key for authenticating with GitHub
#
read -p "Enter your email: " email
ssh-keygen -t ed25519 -C "$email" -f "${GITHUB_SSH_KEY}"
cat "${GITHUB_SSH_KEY}.pub" | pbcopy
echo "The public key (found in '${GITHUB_SSH_KEY}.pub') has been copied to the clipboard. Add it to your GitHub account."
echo "For more details follow the instructions at https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"
read -p "Once done press enter to continue..."

# Prepapre SSH configuration
#
cat <<EOF >> ~/.ssh/config
Host github.com
  HostName github.com
  IdentityFile ${GITHUB_SSH_KEY}
EOF

# Clone the dotfiles repository
#
mkdir -p "${DOTFILES_CLONE_PATH}"
git clone git@github.com:ojizero/dotfiles.git "${DOTFILES_PATH}"

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
export MISE_CONFIG_FILE="${DOTFILES_PATH}/mise.toml"
mise trust "${DOTFILES_PATH}/mise.toml"

# Seed local config if first run
[[ -f mise.local.toml ]] || cp mise.local.toml.sample mise.local.toml

# Single convergence command (symlinks, brew bundle, tools, macOS extras)
mise bootstrap --yes --force-dotfiles
