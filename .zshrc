# Dotfiles root path
#

export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

# Initialize Oh My Zsh
#

export ZSH="${HOME}/.oh-my-zsh"
export ZSH_CUSTOM="${DOTFILES_PATH}/omz"

export ZSH_THEME="avit-copy"

export UPDATE_ZSH_DAYS=13
export DISABLE_UPDATE_PROMPT="true"

export ENABLE_CORRECTION="false"
export COMPLETION_WAITING_DOTS="true"

# Setup ZOxide in place of CD & Z, provides commands aliased behind
#  `cd` and `cdi` as for ease of interactivity
export ZOXIDE_CMD_OVERRIDE='cd'

plugins=(
  asdf
  devops
  zoxide
)

source "${ZSH}/oh-my-zsh.sh"

# Configurations
#

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
