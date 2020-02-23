function docker-into {
  local dopts="${1}"
  local _path="${2}"
  local args="${3}"

  eval "/usr/bin/env docker ${dopts} run -it --rm --volume "${_path}:${_path}" --workdir "${_path}" ${args}"
}

function docker-build {
  local dopts="${1}"
  local args="${2}"

  local default_tag="$(basename ${PWD})"

  if [[ "${args}" = *'--help'* ]] || [[ "${args}" = *'-h'* ]]; then
    eval "/usr/bin/env docker ${dopts} build ${args}"

    return $?
  fi

  if [[ "${args}" != *'--tag'* ]] && [[ "${args}" != *'-t'* ]]; then
    args="--tag ${default_tag} ${args}"
  fi

  if [[ "${args}" != *'--force-rm'* ]] && [[ "${args}" != *'--no-force-rm'* ]]; then
    args="--force-rm ${args}"
  fi

  local targets=$(cat Dockerfile | grep -E '^FROM .* AS .*$' | sed -e 's/FROM .* AS //')
  local caches=''
  local base_tag=$(echo "${args}" | grep -oE ' (--tag|-t)(=| )?([^ ])*')

  if [[ "${args}" != *'--no-progressive-build'* ]]; then
    echo '=== Automatically build multistages in a progressive way'
    echo '=== Each named target will be build independently and used to cache next targets'

    for t in $(echo ${targets}); do
      echo "=== Building target ${t}"

      local target_tag="${default_tag}:${t}"
      local args_changes=" --tag ${target_tag} --target ${t} ${caches}"

      eval "/usr/bin/env docker ${dopts} build $(echo ${args} | sed -e 's/'${base_tag}'/'${args_changes}'/')"

      caches="${caches} --cache-from ${target_tag}"
    done
  fi

  eval "/usr/bin/env docker ${dopts} build ${caches} ${args}"
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
    eval "/usr/bin/env docker ${dopts} --help"

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
    dive) eval "/usr/bin/env docker ${dopts} run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive -- ${@}"
      ;;
    nsenter|enter) eval "/usr/bin/env docker ${dopts} run --rm -it --privileged --pid=host justincormack/nsenter1"
      ;;
    bld|build) docker-build "${dopts}" "${@}"
      ;;
    net) eval "/usr/bin/env docker ${dopts} network ${@}"
      ;;
    ctx) eval "/usr/bin/env docker ${dopts} context ${@}"
      ;;
    ls) eval "/usr/bin/env docker ${dopts} images ${@}"
      ;;
    *) eval "/usr/bin/env docker ${dopts} ${cmd} ${@}"
      ;;
  esac

  return $?
}
