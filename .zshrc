# Initial Oh My Zsh setup
#

export ZSH="/Users/oji/.oh-my-zsh"
export ZSH_THEME="avit"

export DISABLE_UPDATE_PROMPT="true"
export UPDATE_ZSH_DAYS=13

export COMPLETION_WAITING_DOTS="true"
export ENABLE_CORRECTION="false"

plugins=(git z)

source $ZSH/oh-my-zsh.sh

# Languages tooling
#

eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(rbenv init -)"

# Aliases
#

alias k='\kubectl'
if type gls > /dev/null; then
  alias l='\gls -lhtA --color=auto'
else
  alias l='\ls -lhtA'
fi
alias d='\dirs -v'
alias p='\pushd'
alias pp='\popd'
alias mkdir='\mkdir -vp'
alias ipglobal='dig +short myip.opendns.com @resolver1.opendns.com'
alias nsenter='\docker run -it --rm --privileged --pid=host justincormack/nsenter1'
alias dockerdive='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive'
alias dockerclean='docker rmi --force $(docker images -q)'

function _git {
  if [[ $# -gt 0 ]]; then
    \git "$@"
  else
    \git status --short --branch
  fi
}
alias git='_git'
alias g='_git'

function _npm {
  if [[ $# -gt 0 ]]; then
    \npm "$@"
  else
    \npm install
  fi
}
alias npm='_npm'
alias n='_npm'

# Options
#

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups
