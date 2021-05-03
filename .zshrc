# Initial Oh My Zsh setup
#

export ZSH="${HOME}/.oh-my-zsh"
export ZSH_THEME="avit"

export DISABLE_UPDATE_PROMPT="true"
export UPDATE_ZSH_DAYS=13

export COMPLETION_WAITING_DOTS="true"
export ENABLE_CORRECTION="false"

plugins=(git z)

source "${ZSH}/oh-my-zsh.sh"

# Define custom environment variables
#

export NIX_CONFIG="${HOME}/.nix-profile/etc/profile.d/nix.sh"
export ZSH_PROFILE="${HOME}/.zshrc"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Tool related environment variables
#
export AWS_PAGER='less -RFX'
export ERL_AFLAGS="-kernel shell_history enabled"

# Toolings
#

# shellcheck source=/dev/null
if [ -e "${NIX_CONFIG}" ]; then . "${NIX_CONFIG}"; fi

eval "$(thefuck --alias)"

source "$(dirname $(readlink "${ZSH_PROFILE}"))/.docker_shims.zsh"
. <(helm completion zsh)

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

function kubetail {
  selectors="${1}"; shift
  container="${1}"; shift
  kubectl logs -l "${selectors}" -c ${container} $@
}
alias ktail='kubetail'

function kubereleasevolumes {
  released_pvs="$(kubectl get pv -n clickhouse -o json | jq '[.items[]|select(.status.phase=="Released")|.metadata.name]|join(" ")' -r)"

  kubectl delete pv -n clickhouse ${released_pvs[@]}
}
alias kreleasevolumes=kubereleasevolumes

function local-forward {
  local_connection=${1}; shift
  remote_connection=${1}; shift

  ssh -L "${local_connection}:${remote_connection}" $@
}

# Options
#

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
