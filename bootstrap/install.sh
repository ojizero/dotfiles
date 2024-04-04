#! /bin/bash

GITHUB_SSH_KEY=${GITHUB_SSH_KEY:-~/.ssh/github.self}
DOTFILES_CLONE_PATH=${DOTFILES_CLONE_PATH:-~/workspace/self}

# Simply here as a workaround to allow HomeBrew installation to proceed while not being run as root.
# Ref: https://github.com/orgs/Homebrew/discussions/4311#discussioncomment-5240151
#
sudo echo

# Install Homebrew - https://brew.sh/
#
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/oji/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
if ! which brew &>/dev/null; then
  echo 'brew was not installed successfully'
  exit 1
fi

# Install just which is used by the setup scripts - https://just.systems
#
brew install just
if ! which just &>/dev/null; then
  echo 'just was not installed successfully'
  exit 1
fi

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
cd "${DOTFILES_CLONE_PATH}"
git clone git@github.com:ojizero/dotfiles.git

# Run the setup script
#
cd "${DOTFILES_CLONE_PATH}/dotfiles"
just setup
