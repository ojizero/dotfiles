export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)
source "$(brew --prefix asdf)/libexec/asdf.sh"
source <(cat "${DOTFILES_PATH}/omz/auto/"*.zsh)

# This ideally is run earlier on, but for some reason the keybindings bit
# breaks the transient mode, no idea why but moving this here fixes it.
source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
