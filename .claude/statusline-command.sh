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

# ── Helpers ───────────────────────────────────────────────────────────────────
color_for_pct() {
  local pct=$1
  if   [[ "$pct" -le 25 ]]; then echo "$cyan"
  elif [[ "$pct" -le 50 ]]; then echo "$green"
  elif [[ "$pct" -le 75 ]]; then echo "$yellow"
  else                            echo "$red"
  fi
}

circle_for_pct() {
  local pct=$1
  if   [[ "$pct" -ge 75 ]]; then echo "●"
  elif [[ "$pct" -ge 50 ]]; then echo "◕"
  elif [[ "$pct" -ge 25 ]]; then echo "◑"
  elif [[ "$pct" -gt  0  ]]; then echo "◔"
  else                            echo "○"
  fi
}

format_reset_time() {
  local iso_str="$1"
  [[ -z "$iso_str" || "$iso_str" == "null" ]] && return

  local stripped="${iso_str%%.*}"
  stripped="${stripped%%Z}"
  stripped="${stripped%%+*}"

  local epoch
  if [[ "$iso_str" == *"Z"* || "$iso_str" == *"+00:00"* ]]; then
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  else
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  fi
  [[ -z "$epoch" ]] && return

  date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]'
}

# ── Line 1: pwd · git branch + status ────────────────────────────────────────
home_dir="$HOME"
display_path="${cwd/#$home_dir/~}"
[[ -z "$display_path" ]] && display_path="~"

git_part_ansi=""

if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir --no-optional-locks &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if ! git -C "$cwd" diff --quiet --no-optional-locks 2>/dev/null \
     || ! git -C "$cwd" diff --cached --quiet --no-optional-locks 2>/dev/null; then
    dirty="*"
  fi

  arrows=""
  upstream=$(git -C "$cwd" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [[ -n "$upstream" ]]; then
    ahead=$(git -C "$cwd" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    behind=$(git -C "$cwd" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    [[ "$ahead"  -gt 0 ]] && arrows+="⇡"
    [[ "$behind" -gt 0 ]] && arrows+="⇣"
  fi

  git_part_ansi=" ${green}${branch}${reset}"
  [[ -n "$dirty"  ]] && git_part_ansi+=" ${red}${dirty}${reset}"
  [[ -n "$arrows" ]] && git_part_ansi+=" ${cyan}${arrows}${reset}"
fi

# ── Line 2: model · context% ─────────────────────────────────────────────────
line2_ansi=""

if [[ -n "$model" ]]; then
  line2_ansi+="${dim}${model}${reset}"
fi

if [[ -n "$used_pct" ]]; then
  pct=$(printf '%.0f' "$used_pct")
  ctx_color=$(color_for_pct "$pct")
  ctx_circle=$(circle_for_pct "$pct")

  if [[ -n "$line2_ansi" ]]; then
    line2_ansi+=" ${ctx_color}${ctx_circle} ${pct}%${reset}"
  else
    line2_ansi+="${ctx_color}${ctx_circle} ${pct}%${reset}"
  fi
fi

# ── Fetch usage from OAuth API (cached) ──────────────────────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
cache_max_age=60
mkdir -p /tmp/claude 2>/dev/null

needs_refresh=true
usage_data=""

if [[ -f "$cache_file" ]]; then
  cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
  now=$(date +%s)
  cache_age=$(( now - cache_mtime ))
  if [[ "$cache_age" -lt "$cache_max_age" ]]; then
    needs_refresh=false
    usage_data=$(<"$cache_file")
  fi
fi

if $needs_refresh; then
  token=""
  # Try macOS Keychain
  if command -v security &>/dev/null; then
    blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [[ -n "$blob" ]]; then
      token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
  fi

  if [[ -n "$token" && "$token" != "null" ]]; then
    response=$(curl -s --max-time 3 \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if [[ -n "$response" ]] && echo "$response" | jq -e '.five_hour' &>/dev/null; then
      usage_data="$response"
      echo "$response" > "$cache_file"
    fi
  fi
  # Fall back to stale cache
  if [[ -z "$usage_data" && -f "$cache_file" ]]; then
    usage_data=$(<"$cache_file")
  fi
fi

# ── Lines 3-4: rate limits ───────────────────────────────────────────────────
line3_ansi="" line4_ansi=""

if [[ -n "$usage_data" ]] && echo "$usage_data" | jq -e . &>/dev/null; then
  # 5-hour (session) limit
  five_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
  five_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
  five_reset=$(format_reset_time "$five_reset_iso")

  five_col=$(color_for_pct "$five_pct")
  five_circle=$(circle_for_pct "$five_pct")

  line3_ansi="${five_col}${five_circle}${reset} ${dim}session${reset} ${five_col}${five_pct}%${reset}"
  [[ -n "$five_reset" ]] && line3_ansi+=" ${dim}⟳ ${five_reset}${reset}"

  # 7-day (weekly) limit
  seven_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
  seven_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
  seven_reset=$(format_reset_time "$seven_reset_iso")

  seven_col=$(color_for_pct "$seven_pct")
  seven_circle=$(circle_for_pct "$seven_pct")

  line4_ansi="${seven_col}${seven_circle}${reset} ${dim}weekly${reset}  ${seven_col}${seven_pct}%${reset}"
  [[ -n "$seven_reset" ]] && line4_ansi+=" ${dim}⟳ ${seven_reset}${reset}"
fi

# ── Render ────────────────────────────────────────────────────────────────────
line1_ansi="${blue}${display_path}${reset}${git_part_ansi}"

printf "%b" "$line1_ansi"
[[ -n "$line2_ansi" ]] && printf "\n%b" "$line2_ansi"
[[ -n "$line3_ansi" ]] && printf "\n%b" "$line3_ansi"
[[ -n "$line4_ansi" ]] && printf "\n%b" "$line4_ansi"
