# Unified viewer — routes files and stdin to the best available tool.
#
# Usage:
#   view [OPTIONS] [FILE...]
#   command | view [OPTIONS]
#
# Flags:
#   -j, --json     Force JSON mode (fx)
#   -m, --md       Force Markdown mode (glow)
#   -y, --yaml     Force YAML mode (fx)
#   -t, --toml     Force TOML mode (fx)
#   -i, --image    Force image mode (viu)
#   -h, --help     Show help
#

function _view_usage {
  cat >&2 <<'EOF'
Usage: view [OPTIONS] [FILE...]
       command | view [OPTIONS]

Options:
  -j, --json     Force JSON mode (fx)
  -m, --md       Force Markdown mode (glow)
  -y, --yaml     Force YAML mode (fx)
  -t, --toml     Force TOML mode (fx)
  -i, --image    Force image mode (viu)
  -h, --help     Show this help
EOF
}

function _view_file {
  local file="${1}"
  local format="${2}"

  if [[ -z "${format}" ]]; then
    case "${file:e:l}" in
      md)                              format="md" ;;
      json)                            format="json" ;;
      yml|yaml)                        format="yaml" ;;
      toml)                            format="toml" ;;
      png|jpg|jpeg|gif|webp|bmp|svg)   format="image" ;;
    esac
  fi

  case "${format}" in
    md)    glow "${file}" ;;
    json)  fx "${file}" ;;
    yaml)  fx "${file}" ;;
    toml)  fx "${file}" ;;
    image) viu "${file}" ;;
    *)     bat "${file}" ;;
  esac
}

function _view_stdin {
  local format="${1}"

  case "${format}" in
    md)    glow - ;;
    json)  fx ;;
    yaml)  fx ;;
    toml)  fx ;;
    image) viu - ;;
    *)     bat ;;
  esac
}

function view {
  local format=""
  local files=()

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --json|-j)   format="json";  shift ;;
      --md|-m)     format="md";    shift ;;
      --yaml|-y)   format="yaml";  shift ;;
      --toml|-t)   format="toml";  shift ;;
      --image|-i)  format="image"; shift ;;
      --help|-h)   _view_usage; return 0 ;;
      --)          shift; files+=("$@"); break ;;
      -*)          echo "view: unknown option '${1}'" >&2; _view_usage; return 1 ;;
      *)           files+=("${1}"); shift ;;
    esac
  done

  # Stdin mode
  if [[ ${#files[@]} -eq 0 ]]; then
    if [[ -t 0 ]]; then
      _view_usage
      return 1
    fi
    _view_stdin "${format}"
    return $?
  fi

  # File mode
  local rc=0
  for file in "${files[@]}"; do
    if [[ ! -f "${file}" ]]; then
      echo "view: no such file '${file}'" >&2
      rc=1
      continue
    fi
    _view_file "${file}" "${format}"
    (( $? != 0 )) && rc=1
  done
  return ${rc}
}

# Suffix aliases — opening a file by name routes through view
alias -s md='view'
alias -s json='view'
alias -s yml='view'
alias -s yaml='view'
alias -s toml='view'
alias -s png='view'
alias -s jpg='view'
alias -s jpeg='view'
alias -s gif='view'
alias -s webp='view'
alias -s bmp='view'
alias -s svg='view'
