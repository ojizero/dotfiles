function docker-into {
  local dopts="${1}"
  local _path="${2}"
  local args="${3}"

  zsh -c "/usr/bin/env docker ${dopts} run -it --rm --volume "${_path}:${_path}" --workdir "${_path}" ${args}"
}

function docker-build {
  local dopts="${1}"
  local args="${2}"

  local default_tag="$(basename ${PWD})"

  if [[ "${args}" != *'--help'* ]] || [[ "${args}" != *'-h'* ]]; then
    zsh -c "/usr/bin/env docker ${dopts} build ${args}"

    return $?
  fi

  if [[ "${args}" != *'--tag'* ]] && [[ "${args}" != *'-t'* ]]; then
    args="--tag ${default_tag} ${args}"
  fi

  if [[ "${args}" != *'--force-rm'* ]] && [[ "${args}" != *'--no-force-rm'* ]]; then
    args="--force-rm ${args}"
  fi

  # TODO: loop and build each named target individually

  zsh -c "/usr/bin/env docker ${dopts} build ${args}"
}

function docker {
  if [[ $# -eq 0 ]]; then
    docker-build "" "${PWD}"

    return $?
  fi

  ## Docker top level CLI options
  local dopts=''
  while true; do
    case "${1}" in
      --config\
      |-c|--context\
      |-H|--host\
      |-l|--log-level\
      |--tlscacert\
      |--tlscert\
      |--tlskey\
      )
        dopts="${dopts} ${1} ${2}"
        shift 2
        ;;

      -D|--debug\
      |-v|--version\
      |--tls\
      |--tlsverify\
      )
        dopts="${dopts} ${1}"
        shift
        ;;

      *)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    zsh -c "/usr/bin/env docker ${dopts} --help"

    return $?
  fi

  local cmd="${1}"
  shift

  case "${cmd}" in
    into)
      local _path="${1}"
      shift
      docker-into "${dopts}" "${_path}" "${@}"
      ;;
    here) docker-into "${dopts}" "${PWD}" "${@}"
      ;;
    bld|build) docker-build "${dopts}" "${@}"
      ;;
    net) zsh -c "/usr/bin/env docker ${dopts} network ${@}"
      ;;
    ctx) zsh -c "/usr/bin/env docker ${dopts} context ${@}"
      ;;
    ls) zsh -c "/usr/bin/env docker ${dopts} images ${@}"
      ;;
    *) zsh -c "/usr/bin/env docker ${dopts} ${cmd} ${@}"
      ;;
  esac

  return $?
}
