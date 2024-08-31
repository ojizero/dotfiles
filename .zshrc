export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

autoload -U compinit && compinit
autoload -U +X bashcompinit && bashcompinit

source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)
source <(tailscale completion zsh)

source "$(brew --prefix asdf)/libexec/asdf.sh"
fpath+=("$(brew --prefix asdf)/share/zsh/site-functions")
autoload -Uz _asdf
compdef _asdf asdf

for auto in "${DOTFILES_PATH}/omz/auto/"*.zsh; do
  source "${auto}"
done

# More sane `pushd` settings
unsetopt auto_pushd
setopt pushd_ignore_dups
