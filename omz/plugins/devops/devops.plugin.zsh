alias k='\kubectl'
alias tf='\terraform'
alias nsenter='\docker run -it --rm --privileged --pid=host justincormack/nsenter1'
alias dockerdive='\docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive'
alias dockerclean='\docker rmi --force $(docker images -q)'
alias dockerremovedangles='\docker rmi --force $(docker images -f "dangling=true" -q)'

function kubetail {
  selectors="${1}"; shift
  container="${1}"; shift
  kubectl logs -l "${selectors}" -c ${container} $@
}
alias ktail='kubetail'

function local-forward {
  local_connection=${1}; shift
  remote_connection=${1}; shift

  ssh -L "${local_connection}:${remote_connection}" -N $@
}

function listening {
  if [ $# -eq 0 ]; then
    sudo lsof -iTCP -sTCP:LISTEN -n -P
  elif [ $# -eq 1 ]; then
    sudo lsof -iTCP -sTCP:LISTEN -n -P | grep -i --color $1
  else
    echo "Usage: listening [pattern]" >&2
  fi
}
