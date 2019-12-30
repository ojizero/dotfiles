# Initial Oh My Zsh setup
#

export ZSH="/Users/oji/.oh-my-zsh"
export ZSH_THEME="avit"

export DISABLE_UPDATE_PROMPT="true"
export UPDATE_ZSH_DAYS=13

export ENABLE_CORRECTION="true"

export COMPLETION_WAITING_DOTS="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# Languages tooling
#

eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(rbenv init -)"

# Aliases
#

alias g='\git'
alias k='\kubectl'
alias l='\ls -lhtA'
alias d='\dirs -v'
alias p='\pushd'
alias pp='\popd'
alias mkdir='\mkdir -vp'
