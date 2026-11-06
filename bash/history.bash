# History settings, same intent as zsh/omz/auto/history.zsh

HISTFILE="${HOME}/.bash_history"
HISTSIZE=50000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups # ignore duplicates and commands that start with space
HISTTIMEFORMAT='%F %T '          # record timestamp of command

shopt -s histappend # append to HISTFILE instead of overwriting it
shopt -s histverify # show command with history expansion before running it

# Write each command to HISTFILE at once, so other shells can read it
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; ${PROMPT_COMMAND}}"
