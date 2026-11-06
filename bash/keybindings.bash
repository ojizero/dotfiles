# Readline settings, same intent as zsh/omz/auto/keybindings.zsh and completions.zsh

set -o emacs

# Start typing + [Up/Down-Arrow] - search history for lines that start with it
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# [Ctrl-RightArrow] / [Ctrl-LeftArrow] - move one word
bind '"\e[1;5C": forward-word'
bind '"\e[1;5D": backward-word'

# [Ctrl-Delete] - delete whole forward-word
bind '"\e[3;5~": kill-word'

# [Ctrl-U] - delete from cursor to beginning of line (not whole line)
bind '"\C-u": unix-line-discard'

# [Esc-w] - Kill from the cursor to the mark
bind '"\ew": kill-region'

# [Esc-l] - run command: ls
bind '"\el": "ls\n"'

# [Shift-Enter] / [Ctrl-Enter] - accept line (Ghostty fixterms encoding: CSI 27;<mod>;13~)
bind '"\e[27;2;13~": accept-line'
bind '"\e[27;5;13~": accept-line'

# Case and hyphen insensitive completion, menu on successive tab press
bind 'set completion-ignore-case on'
bind 'set completion-map-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
