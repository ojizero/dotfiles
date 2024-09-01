export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)
source "$(brew --prefix asdf)/libexec/asdf.sh"

for auto in "${DOTFILES_PATH}/omz/auto/"*.zsh; do
  source "${auto}"
done
