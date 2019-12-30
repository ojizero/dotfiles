# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/oji/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
export ZSH_THEME="robbyrussell"

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
