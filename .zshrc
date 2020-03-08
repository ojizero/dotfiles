# Initial Oh My Zsh setup
#

export ZSH="/Users/oji/.oh-my-zsh"
export ZSH_THEME="avit"

export DISABLE_UPDATE_PROMPT="true"
export UPDATE_ZSH_DAYS=13

export COMPLETION_WAITING_DOTS="true"
export ENABLE_CORRECTION="false"

plugins=(git z)

source "${ZSH}/oh-my-zsh.sh"

# Define custom environment variables
#

export ZSH_PROFILE="${HOME}/.zshrc"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Toolings
#

eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(rbenv init -)"
eval "$(thefuck --alias)"

source "$(dirname $(readlink "${ZSH_PROFILE}"))/.docker_shims.zsh"

# Aliases and functions
#

alias f='\fuck'
alias k='\kubectl'
if type gls > /dev/null; then
  alias l='\gls -lhA --color=auto --group-directories-first'
  alias ls='\gls -lhA --color=auto --group-directories-first'
else
  alias l='\ls -lhA'
  alias ls='\ls -lhA'
fi
alias d='\dirs -v'
alias p='\pushd'
alias pp='\popd'
alias tf='\terraform'
alias mkdir='\mkdir -vp'
alias ipglobal='\dig +short myip.opendns.com @resolver1.opendns.com'
alias sudo='sudo ' # This allows for using aliases under sudo
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

function vagrant {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env vagrant $@
  else
    /usr/bin/env vagrant up
  fi
}
alias v='vagrant'

# Options
#

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups
