# Append additional custom completions paths
fpath+=("$(brew --prefix)/share/zsh/site-functions")
fpath+=("${DOTFILES_PATH}/omz/completions")
autoload -U compinit && compinit
autoload -U +X bashcompinit && bashcompinit

# Code taken from OhMyZsh
# https://github.com/ohmyzsh/ohmyzsh/blob/2056aeeeaddd977eb205619c6f236b94dac896be/lib/completion.zsh

zmodload -i zsh/complist

unsetopt menu_complete   # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu         # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

bindkey -M menuselect '^o' accept-and-infer-next-history
zstyle ':completion:*:*:*:*:*' menu select

# The case insensitive, hyphen insensitive, code path
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'

# Complete . and .. special directories
zstyle ':completion:*' special-dirs true

zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

# # disable named-directories autocompletion
# zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
