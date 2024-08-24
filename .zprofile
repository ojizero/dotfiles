# Load Homebrew packages and binaries
#
# This differs between Apple Silicon and Intel based
# Macs so we check the machine architecture before
case "$(machine)" in
  arm*)
    eval "$(/opt/homebrew/bin/brew shellenv)"

    ;;

  x86_64*)
    eval "$(/usr/local/bin/brew shellenv)"

    ;;
esac

# Load `m` into the env
mpath="$(readlink -f ~/.zprofile | xargs dirname)/m"
export PATH="${mpath}:${PATH}"

if [[ -f "${HOME}/.local/.zprofile" ]]; then
  source "${HOME}/.local/.zprofile"
fi
