export DOTFILES_PATH="$(dirname $(readlink ${HOME}/.zshrc))"

# Disable it when running in Claude as a workaround for issue
# https://github.com/anthropics/claude-code/issues/2407
[ "${CLAUDECODE}" != "1" ] && source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)

eval "$(mise activate zsh)"
source <(cat "${DOTFILES_PATH}/omz/auto/"*.zsh)
source "${DOTFILES_PATH}/omz/plugins/view/view.zsh"

# This ideally is run earlier on, but for some reason the keybindings bit
# breaks the transient mode, no idea why but moving this here fixes it.
source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
