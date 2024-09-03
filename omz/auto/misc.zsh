# Directory config
setopt pushd_ignore_dups
alias -- -='cd -'

# Tool related environment variables
#

export HOMEBREW_NO_ANALYTICS=1
export PAGER='less -RFX'
export AWS_PAGER='less -RFX'
export ERL_AFLAGS="-kernel shell_history enabled"
export ASDF_GOLANG_MOD_VERSION_ENABLED=true

# Misc configs, taken from OhMyZsh
# https://github.com/ohmyzsh/ohmyzsh/blob/2056aeeeaddd977eb205619c6f236b94dac896be/lib/misc.zsh
setopt multios              # enable redirect to multiple streams: echo >file1 >file2
setopt long_list_jobs       # show long list format job notifications
setopt interactivecomments  # recognize comments

# WORDCHARS A list of non-alphanumeric characters considered part of a word
# by the line editor.
#
# Set to nothing to make it make more sense + be more in line with how i'm used
# to it coming from OhMyzsh.
export WORDCHARS=''
