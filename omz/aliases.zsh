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
