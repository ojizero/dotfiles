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

function glow {
  local style="${DOTFILES_PATH}/glow/themes/catppuccin-mocha.json"
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" != "Dark" ]]; then
    style="${DOTFILES_PATH}/glow/themes/catppuccin-latte.json"
  fi

  local tui=1
  [[ ! -t 1 ]] && tui=0
  local args=()
  for arg in "$@"; do
    case "${arg}" in
      --tui|-t)       ;;                         # already the default, strip
      --no-tui|-T)    tui=0 ;;                   # suppress TUI, strip
      --pager|-p)     tui=0; args+=("${arg}") ;; # pager implies no TUI
      *)              args+=("${arg}") ;;
    esac
  done

  if (( tui )); then
    # Workaround: glow --tui ignores -w; pipe via cat to fix terminal width
    local flags=() sources=() i=1
    while (( i <= ${#args[@]} )); do
      case "${args[$i]}" in
        --width=*|--style=*|--config=*)
          flags+=("${args[$i]}") ;;
        -[ws]|--width|--style|--config)
          flags+=("${args[$i]}" "${args[$((i+1))]}")
          (( i++ )) ;;
        --)
          sources+=("${args[$((i+1)),-1]}")
          break ;;
        -?*)
          flags+=("${args[$i]}") ;;
        *)
          sources+=("${args[$i]}") ;;
      esac
      (( i++ ))
    done
    if [[ ${#sources[@]} -gt 0 ]]; then
      cat "${sources[@]}" | command glow -s "${style}" --tui --line-numbers -w $(( $(tput cols) - 4 )) "${flags[@]}"
    else
      command glow -s "${style}" --tui --line-numbers -w $(( $(tput cols) - 4 )) "${flags[@]}"
    fi
  else
    command glow -s "${style}" "${args[@]}"
  fi
}

# Reset terminal state after Claude Code exits — it can leave bracketed paste,
# application cursor keys, and other modes stuck on dirty exit.
function claude {
  command claude "$@"
  printf '\e[?2004l\e[?1l\e[?25h'
}
alias cc='claude --dangerously-skip-permissions'
alias xclaude='CLAUDE_CONFIG_DIR="$HOME/.claude-x" claude --dangerously-skip-permissions'
alias xcc='xclaude'

alias m='mise run'

# npx/uvx-style ephemeral tool runners, routed through mise instead
# Usage: npx <package>[@version] [args] / uvx <package>[@version] [args]
function npx {
  local pkg="${1:?required input of package to run}"; shift
  local bin="${pkg%@*}"; [[ -z "${bin}" ]] && bin="${pkg}" # scoped pkg without version
  mise x "npm:${pkg}" -- "${bin##*/}" "$@"
}

function uvx {
  local pkg="${1:?required input of package to run}"; shift
  mise x "pipx:${pkg}" -- "${pkg%@*}" "$@"
}

alias v='nvim'
alias nv='nvim'
alias vm='nvim'
alias vim='nvim'
