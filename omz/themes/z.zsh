## Transient mode sourced from https://github.com/gusye1234/Gus-zsh-theme/tree/main
## but then adjusted to look the way I want and be more similar to avit
## https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/avit.zsh-theme

# Determine the time since last commit. If branch is clean,
# use a neutral color, otherwise colors will vary according to time.
function _git_time_since_commit() {
  local last_commit now seconds_since_last_commit
  local minutes hours days years commit_age
  # Only proceed if there is actually a commit.
  if last_commit=$(command git -c log.showSignature=false log --format='%at' -1 2>/dev/null); then
    now=$(date +%s)
    seconds_since_last_commit=$((now-last_commit))

    # Totals
    minutes=$((seconds_since_last_commit / 60))
    hours=$((minutes / 60))
    days=$((hours / 24))
    years=$((days / 365))

    if [[ $years -gt 0 ]]; then
      commit_age="${years}y$((days % 365 ))d"
    elif [[ $days -gt 0 ]]; then
      commit_age="${days}d$((hours % 24))h"
    elif [[ $hours -gt 0 ]]; then
      commit_age+="${hours}h$(( minutes % 60 ))m"
    else
      commit_age="${minutes}m"
    fi

    echo "${ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL}${commit_age}%{$reset_color%}"
  fi
}

PROMPT='
%{$fg[blue]%}%3~%{$reset_color%} $(git_prompt_info)
%(?:%{$fg[green]%}❯ :%{$fg[red]%}❯ )%{$reset_color%}'
PROMPT2='%{$fg[grey]%}❯   %{$reset_color%}'

RPROMPT='%{$(echotc UP 1)%}$(_git_time_since_commit) $(git_prompt_status) %{$fg_bold[red]%}%(?..⍉)%{$reset_color%}%{$(echotc DO 1)%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}" # \e[1;38;5;239m <- bold grey
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%} *%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%}✚ "
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%}⚑ "
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%}✖ "
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%}▴ "
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[cyan]%}§ "
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[white]%}◒ "
ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT="%{$fg[green]%}"
ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM="%{$fg[yellow]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG="%{$fg[red]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL="%{$fg[white]%}"

# Enable command search with Up and Down arrow key
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search   # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# Enable transient prompt
zle-line-init() {
    emulate -L zsh

    [[ $CONTEXT == start ]] || return 0

    while true; do
        zle .recursive-edit
        local -i ret=$?
        [[ $ret == 0 && $KEYS == $'\4' ]] || break
        [[ -o ignore_eof ]] || exit 0
    done

    local saved_prompt=$PROMPT
    local saved_prompt2=$PROMPT2
    local saved_rprompt=$RPROMPT
    PROMPT='
%(?:%{$fg[green]%}❯ :%{$fg[red]%}❯ )%{$reset_color%}'
    PROMPT2='%(?:%{$fg[green]%}❯ :%{$fg[red]%}❯ )%{$reset_color%}'

    RPROMPT=''
    zle .reset-prompt
    PROMPT=$saved_prompt
    PROMPT2=$saved_prompt2
    RPROMPT=$saved_rprompt

    if ((ret)); then
        zle .send-break
    else
        zle .accept-line
    fi
    return ret
}

zle -N zle-line-init
