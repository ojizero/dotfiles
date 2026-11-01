# Canonical clone path — keep in sync with mise.toml [env] DOTFILES_PATH
export DOTFILES_PATH="${DOTFILES_PATH:-${HOME}/workspace/self/dotfiles}"

# Non-login shells on Linux (e.g. `ssh host cmd`) skip .zprofile, load Homebrew here as a fallback
[[ -z "${HOMEBREW_PREFIX}" && -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# This seems to break Claude, but at this point I don't really care to hack around it.
# https://github.com/anthropics/claude-code/issues/2407
source <(zoxide init --cmd "${ZOXIDE_CMD_OVERRIDE:-cd}" zsh)

# GUI apps read PATH once from a probe shell outside any project. Shims there
# pick each tool's version from the cwd later; full activation would freeze
# the versions of the folder the probe ran in (T3 Code, VS Code, Cursor)
if [[ -o interactive && ( "${ZSH_EXECUTION_STRING}" == *__T3CODE_ENV_* || -n "${VSCODE_RESOLVING_ENVIRONMENT}" ) ]]; then
  eval "$(mise activate zsh --shims)"
else
  eval "$(mise activate zsh)"
fi
source <(cat "${DOTFILES_PATH}/omz/auto/"*.zsh)
source "${DOTFILES_PATH}/omz/plugins/view/view.zsh"

# This ideally is run earlier on, but for some reason the keybindings bit
# breaks the transient mode, no idea why but moving this here fixes it.
source <(oh-my-posh init zsh --config "${DOTFILES_PATH}/omp.toml")
