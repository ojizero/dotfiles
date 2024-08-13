#!/usr/bin/env just --justfile

set quiet

cfg_zshrc := "${PWD}/.zshrc"
home_zshrc := "${HOME}/.zshrc"

cfg_zprofile := "${PWD}/.zprofile"
home_zprofile := "${HOME}/.zprofile"

cfg_gitconfig := "${PWD}/.gitconfig"
home_gitconfig := "${HOME}/.gitconfig"

cfg_local_gitconfig := "${PWD}/.local/.gitconfig"
home_local_gitconfig := "${HOME}/.local.gitconfig"

cfg_aws := "${PWD}/.aws"
home_aws := "${HOME}/.aws"

cfg_asdf := "${PWD}/.asdfrc"
home_asdf := "${HOME}/.asdfrc"

cfg_tool_versions := "${PWD}/.tool-versions"
home_tool_versions := "${HOME}/.tool-versions"

cfg_justfile := "${PWD}/just/.justfile"
home_justfile := "${HOME}/.justfile"

cfg_justfile_imports := "${PWD}/just/.imports.justfile"
home_justfile_imports := "${HOME}/.imports.justfile"

cfg_homebrew_aliases := "${PWD}/.brew-aliases"
home_homebrew_aliases := "${HOME}/.brew-aliases"

default: setup

setup: brew config-zsh config-git config-aws asdf set-global-justfile

brew +opts='': _install_homebrew_if_missing _setup_homebrew_configs
  brew bundle {{opts}}

config-zsh: _install_ohmyzsh_if_missing
  rm -fr {{home_zshrc}}
  ln -s {{cfg_zshrc}} {{home_zshrc}}

  rm -fr {{home_zprofile}}
  ln -s {{cfg_zprofile}} {{home_zprofile}}

config-git:
  rm -fr {{home_gitconfig}}
  ln -s {{cfg_gitconfig}} {{home_gitconfig}}

  rm -fr {{home_local_gitconfig}}
  ln -s {{cfg_local_gitconfig}} {{home_local_gitconfig}}

config-aws:
  rm -fr {{home_aws}}
  ln -s {{cfg_aws}} {{home_aws}}

asdf: _install_asdf_plugins
  rm -fr {{home_asdf}}
  ln -s {{cfg_asdf}} {{home_asdf}}

  rm -fr {{home_tool_versions}}
  ln -s {{cfg_tool_versions}} {{home_tool_versions}}

  asdf install

set-global-justfile: _build_justfile_imports
  rm -fr {{home_justfile}}
  ln -s {{cfg_justfile}} {{home_justfile}}

  rm -fr {{home_justfile_imports}}
  ln -s {{cfg_justfile_imports}} {{home_justfile_imports}}

_install_ohmyzsh_if_missing:
  #!/usr/bin/env bash
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

_install_homebrew_if_missing:
  #!/usr/bin/env bash
  if ! type brew >/dev/null 2>&1; then
    /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi

_setup_homebrew_configs:
  rm -fr {{home_homebrew_aliases}}
  ln -s {{cfg_homebrew_aliases}} {{home_homebrew_aliases}}

_install_asdf_plugins:
  asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
  asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
  asdf plugin-add terraform https://github.com/asdf-community/asdf-hashicorp.git
  asdf plugin-add terraform-ls https://github.com/asdf-community/asdf-hashicorp.git

_build_justfile_imports:
  cat "${PWD}/just/template.imports.justfile" \
    | sed "s|__DOTFILES_PATH__|${PWD}|g" \
    > "${PWD}/just/.imports.justfile"
