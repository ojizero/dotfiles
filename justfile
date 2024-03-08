cfg_zshrc := "${PWD}/.zshrc"
home_zshrc := "${HOME}/.zshrc"

cfg_gitconfig := "${PWD}/.gitconfig"
home_gitconfig := "${HOME}/.gitconfig"

cfg_aws := "${PWD}/.aws"
home_aws := "${HOME}/.aws"

default: setup

setup: brew config-zsh config-git config-aws

@brew +opts='': _install_homebrew_if_missing
	brew bundle {{opts}}

@config-zsh: _install_ohmyzsh_if_missing
	rm -fr {{home_zshrc}}
	ln -s {{cfg_zshrc}} {{home_zshrc}}

@config-git:
	rm -fr {{home_gitconfig}}
	ln -s {{cfg_gitconfig}} {{home_gitconfig}}

@config-aws:
	rm -fr {{home_aws}}
	ln -s {{cfg_aws}} {{home_aws}}

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

# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
