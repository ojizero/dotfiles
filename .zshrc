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

# Toolings
#

eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(rbenv init -)"
eval "$(thefuck --alias)"

# Aliases and functions
#

alias f='\fuck'
alias k='\kubectl'
alias v='\vagrant'
if type gls > /dev/null; then
  alias ls='\gls -G --color=auto'
  alias l='\gls -lhA --color=auto --group-directories-first'
else
  alias l='\ls -lhA'
fi
alias d='\dirs -v'
alias p='\pushd'
alias pp='\popd'
alias mkdir='\mkdir -vp'
alias ipglobal='\dig +short myip.opendns.com @resolver1.opendns.com'
alias nsenter='\docker run -it --rm --privileged --pid=host justincormack/nsenter1'
alias dockerdive='\docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive'
alias dockerclean='\docker rmi --force $(docker images -q)'

function git {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env git $@
  else
    /usr/bin/env git status --short --branch
  fi
}
alias g='git'

function hub {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env hub $@
  else
    /usr/bin/env hub status --short --branch
  fi
}
alias gh='hub'
alias github='hub'

function npm {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env npm $@
  else
    /usr/bin/env npm install
  fi
}
alias n='npm'

# Options
#

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups
