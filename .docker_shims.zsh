function docker-into {
  local input="${@}"

  local dopts="${input% // *}"
  local dopts="${dopts% // *}"

  local _path="${input% // *}"
  local _path="${_path#* // }"

  local args="${input#* // }"
  local args="${args#* // }"

  eval "/usr/bin/env docker ${dopts} run -it --rm --volume "${_path}:${_path}" --workdir "${_path}" ${args}"
}

function docker-run {
  local input="${@}"

  local dopts="${input% // *}"
  local args="${input#* // }"

  if [[ "${args}" = *'--no-rm'* ]]; then
    # --no-rm isn't a real flag so we remove it
    args=$(echo "${args}" | sed -e 's/--no-rm//g')
  elif [[ "${args}" != *'--rm'* ]]; then
    args="--rm ${args}"
  fi

  eval "/usr/bin/env docker ${dopts} run ${args}"
}

function docker-build {
  local input="${@}"

  local dopts="${input% // *}"
  local args="${input#* // }"

  local default_tag="$(basename ${PWD})"

  if [[ "${args}" = *'--help'* ]] || [[ "${args}" = *'-h'* ]]; then
    eval "/usr/bin/env docker ${dopts} build ${args}"

    return $?
  fi

  if [[ "${args}" != *'--tag'* ]] && [[ "${args}" != *'-t'* ]]; then
    args="--tag ${default_tag} ${args}"
  fi

  if [[ "${args}" = *'--no-force-rm'* ]]; then
    # --no-force-rm isn't a real flag so we remove it
    args=$(echo "${args}" | sed -e 's/--no-force-rm//g')
  elif [[ "${args}" != *'--force-rm'* ]]; then
    args="--force-rm ${args}"
  fi

  local targets=$(cat Dockerfile | grep -E '^FROM .* AS .*$' | sed -e 's/FROM .* AS //')
  local caches=''
  local base_tag=$(echo "${args}" | grep -oE ' (--tag|-t)(=| )?([^ ])*')

  if [[ "${args}" != *'--no-progressive-build'* ]]; then
    echo '=== Automatically build multistages in a progressive way' >&2
    echo '=== Each named targets will be built independently and used to cache next targets' >&2

    for t in $(echo ${targets}); do
      echo "=== Building target '${t}'" >&2

      local target_tag="${default_tag}:${t}"
      local args_changes=" --tag ${target_tag} --target ${t} ${caches}"

      eval "/usr/bin/env docker ${dopts} build $(echo ${args} | sed -e 's/'${base_tag}'/'${args_changes}'/')"

      local s=$?
      if [[ $s -ne 0 ]]; then
        echo "=== Docker failed to build target '${t}'" >&2

        return $s
      fi

      caches="${caches} --cache-from ${target_tag}"
    done
  else
    # --no-progressive-build isn't a real flag so we remove it
    args=$(echo "${args}" | sed -e 's/--no-progressive-build//g')
  fi

  eval "/usr/bin/env docker ${dopts} build ${caches} ${args}"
}

function docker-remove-dangling {
  local input="${@}"

  local dopts="${input% // *}"
  local args="${input#* // }"

  local dangling_images=$(eval "/usr/bin/env docker ${dopts} images --filter dangling=true --quiet")

  local s=$?
  if [[ $s -ne 0 ]]; then
    echo '=== Docker failed to query dangling images' >&2
    echo "${dangling_images}" >&2

    return $s
  fi

  eval "/usr/bin/env docker ${dopts} rmi ${args} ${dangling_images}"
}

function docker {
  if [[ $# -eq 0 ]]; then
    docker-build " // ${PWD}"

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
        dopts="${dopts} ${1} ${2}"; shift 2
        ;;

      -D|--debug\
      |-v|--version\
      |--tls\
      |--tlsverify\
      )
        dopts="${dopts} ${1}"; shift
        ;;

      --no-shim)
        local __no_shim='__true__'; shift
        echo '=== The command will be run as is without Shim function intervening' >&2
        ;;

      *)
        break
        ;;
    esac
  done

  if [[ "${__no_shim}" = '__true__' ]]; then
    echo "=== Evaluating the command [[ /usr/bin/env docker ${dopts} ${@} ]] as is" >&2
    eval "/usr/bin/env docker ${dopts} ${@}"
    return $?
  fi

  if [[ $# -eq 0 ]]; then
    eval "/usr/bin/env docker ${dopts} --help"

    return $?
  fi

  local cmd="${1}"; shift

  case "${cmd}" in
    into)
      local _path="${1}"; shift
      docker-into "${dopts} // ${_path} // ${@}"
      ;;
    here) docker-into "${dopts} // ${PWD} // ${@}"
      ;;
    dive) eval "/usr/bin/env docker ${dopts} run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive -- ${@}"
      ;;
    nsenter|enter) eval "/usr/bin/env docker ${dopts} run --rm -it --privileged --pid=host justincormack/nsenter1"
      ;;
    bld|build) docker-build "${dopts} // ${@}"
      ;;
    run) docker-run "${dopts} // ${@}"
      ;;
    rmd|rmdangling) docker-remove-dangling "${dopts} // ${@}"
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
