# Aliases and functions
#

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
alias mkdir='\mkdir -vp'
alias ipglobal='\dig +short myip.opendns.com @resolver1.opendns.com'
alias sudo='sudo ' # This allows for using aliases under sudo

function git {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env git $@
  else
    /usr/bin/env git status --short --branch
  fi
}
alias g='git'
alias gg='git gone'
alias lg='lazygit'

function npm {
  if [[ $# -gt 0 ]]; then
    /usr/bin/env npm $@
  else
    /usr/bin/env npm install
  fi
}
alias n='npm'

function cheat {
  curl "https://cht.sh/${1}"
}

# Find up in zsh because why not...
# Consider replacing with gofindup?
find-up() {
  f="${1:?required input of file name to look for}"
  cur="${2:-${PWD}}"
  testing="$(echo "${cur}/${f}" | tr -s /)"
  while [[ ! -f "${testing}" ]]; do
    cur="$(dirname ${cur})"
    testing="$(echo "${cur}/${f}" | tr -s /)"
    [[ "${cur}" = "/" ]] && [[ ! -f "${testing}" ]] && return 0
  done
  echo "${testing}"
}

alias -s md='bat'

alias yless='jless --yaml'
alias -s json='jless'
alias -s yml='yless'
alias -s yaml='yless'
