export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

# Set the shell theme
source "${DOTFILES_PATH}/omz/themes/z.zsh"
# Set `cd` to use zoxide
eval "$(zoxide init --cmd ${ZOXIDE_CMD_OVERRIDE:-cd} zsh)"

for conf in ${DOTFILES_PATH}/omz/*.zsh; do
  source "${conf}"
done

## p
## TODO: is this needed?
##

fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups

autoload -U +X bashcompinit && bashcompinit
