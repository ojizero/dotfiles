# Load Homebrew packages and binaries
eval "$(/opt/homebrew/bin/brew shellenv)"

# Load `m` into the env
mpath="$(readlink -f ~/.zprofile | xargs dirname)/m"
export PATH="${mpath}:${PATH}"

if [[ -f "~/.local/.zprofile" ]]; then
  source "~/.local/.zprofile"
fi
