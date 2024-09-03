alias k='\kubectl'
alias tf='\terraform'
alias nsenter='\docker run -it --rm --privileged --pid=host justincormack/nsenter1'
alias dockerdive='\docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive'
alias dockerclean='\docker rmi --force $(docker images -q)'
alias dockerremovedangles='\docker rmi --force $(docker images -f "dangling=true" -q)'

function kubetail {
  selectors="${1?:selectors is a required input}"
  container="${2?:container is a required input}"
  shift 2
  kubectl logs -l "${selectors}" -c ${container} $@
}
alias ktail='kubetail'

function local-forward {
  local_connection="${1:?local connection is a required input}"
  remote_connection="${2:?remote connection is a required input}"
  shift 2
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
