# Load Homebrew packages and binaries
#
# This differs between Apple Silicon and Intel based
# Macs so we check the machine architecture before,
# on Linux Homebrew lives under /home/linuxbrew
if [[ "$(uname -s)" == "Darwin" ]]; then
  case "$(machine)" in
    arm*)
      eval "$(/opt/homebrew/bin/brew shellenv)"
      ;;

    x86_64*)
      eval "$(/usr/local/bin/brew shellenv)"
      ;;
  esac
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if [[ -d "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# Mise shims for non-interactive shells (IDEs, scripts, cron)
# Interactive shells use `mise activate bash` in .bashrc instead
[[ $- != *i* ]] && eval "$(mise activate bash --shims)"

# Login shells skip .bashrc, so interactive ones load it here
[[ $- == *i* && -f "${HOME}/.bashrc" ]] && source "${HOME}/.bashrc"
