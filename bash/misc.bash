# Tool related environment variables, same as omz/auto/misc.zsh
#

export HOMEBREW_NO_ANALYTICS=1

# We allow for EDITOR to be predefined for cases where
# we want this to be controlled externally, e.g. in
# case the terminal is coming from a code editor
# that sets this value for us.
export EDITOR="${EDITOR:-nvim}"

export PAGER='less -RFX'
export AWS_PAGER='less -RFX'

[[ $- == *i* ]] || return 0

# Directory config
alias -- -='cd -'

shopt -s checkwinsize # update LINES and COLUMNS after each command
shopt -s globstar     # ** matches across directories, as in zsh

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
