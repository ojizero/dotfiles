#!/usr/bin/env zsh

input=$(cat)

# ── Parse JSON input ──────────────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // ""')

# ── ANSI color codes ──────────────────────────────────────────────────────────
reset=$'\033[0m'
blue=$'\033[34m'
green=$'\033[32m'
red=$'\033[31m'
cyan=$'\033[36m'
yellow=$'\033[33m'
dim=$'\033[2m'

# ── Left side: pwd ────────────────────────────────────────────────────────────
home_dir="$HOME"
display_path="${cwd/#$home_dir/~}"
[[ -z "$display_path" ]] && display_path="~"

# ── Left side: git branch + status ───────────────────────────────────────────
git_part_plain=""
git_part_ansi=""

if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  # Dirty check (working tree or index)
  dirty=""
  if ! git -C "$cwd" diff --quiet 2>/dev/null \
     || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
    dirty="*"
  fi

  # Ahead / behind upstream
  arrows=""
  upstream=$(git -C "$cwd" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [[ -n "$upstream" ]]; then
    ahead=$(git -C "$cwd" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    behind=$(git -C "$cwd" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    [[ "$ahead"  -gt 0 ]] && arrows+="⇡"
    [[ "$behind" -gt 0 ]] && arrows+="⇣"
  fi

  # Plain (for width calc)
  git_part_plain=" ${branch}"
  [[ -n "$dirty"  ]] && git_part_plain+=" ${dirty}"
  [[ -n "$arrows" ]] && git_part_plain+=" ${arrows}"

  # Colored (mirrors omp: branch=green, dirty=red, arrows=cyan)
  git_part_ansi=" ${green}${branch}${reset}"
  [[ -n "$dirty"  ]] && git_part_ansi+=" ${red}${dirty}${reset}"
  [[ -n "$arrows" ]] && git_part_ansi+=" ${cyan}${arrows}${reset}"
fi

# ── Right side: model · context% ─────────────────────────────────────────────
# Separator: middle dot "·" (U+00B7) — lighter than bullet •
sep=" · "
right_plain=""
right_ansi=""

if [[ -n "$model" ]]; then
  right_plain+="$model"
  right_ansi+="${dim}${model}${reset}"
fi

if [[ -n "$used_pct" ]]; then
  pct=$(printf '%.0f' "$used_pct")

  # Color ramp by usage: cyan ≤25%, green ≤50%, yellow ≤75%, red >75%
  if   [[ "$pct" -le 25 ]]; then ctx_color="$cyan"
  elif [[ "$pct" -le 50 ]]; then ctx_color="$green"
  elif [[ "$pct" -le 75 ]]; then ctx_color="$yellow"
  else                            ctx_color="$red"
  fi

  if [[ -n "$right_plain" ]]; then
    right_plain+="${sep}${pct}%"
    right_ansi+="${dim}${sep}${reset}${ctx_color}${pct}%${reset}"
  else
    right_plain+="${pct}%"
    right_ansi+="${ctx_color}${pct}%${reset}"
  fi
fi


# ── Width calculation ─────────────────────────────────────────────────────────
left_plain="${display_path}${git_part_plain}"
left_len=${#left_plain}
right_len=${#right_plain}

# Claude Code doesn't pass terminal width to statusline commands ($COLUMNS=0,
# tput cols=80). Read the actual width from the parent process's TTY device.
parent_tty=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
if [[ -n "$parent_tty" && -e "/dev/$parent_tty" ]]; then
  term_width=$(stty size <"/dev/$parent_tty" 2>/dev/null | awk '{print $2}')
fi
[[ -z "$term_width" || "$term_width" -eq 0 ]] && term_width=80

# Claude Code's TUI has ~2 chars of padding on each side.
chrome=5
pad=$(( term_width - left_len - right_len - chrome ))

# ── Render ────────────────────────────────────────────────────────────────────
left_ansi="${blue}${display_path}${reset}${git_part_ansi}"

printf "%b%${pad}s%b" "$left_ansi" "" "$right_ansi"
