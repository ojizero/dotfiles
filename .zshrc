export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)
source "$(brew --prefix asdf)/libexec/asdf.sh"
source <(tailscale completion zsh)

for auto in "${DOTFILES_PATH}/omz/auto/"*; do
  source "${auto}"
done

fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups

autoload -U +X bashcompinit && bashcompinit
