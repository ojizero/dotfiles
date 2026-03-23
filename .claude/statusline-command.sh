#!/usr/bin/env zsh

input=$(cat)

# ── Parse JSON input ──────────────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // ""')
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# ── ANSI color codes ──────────────────────────────────────────────────────────
reset=$'\033[0m'
blue=$'\033[34m'
green=$'\033[32m'
red=$'\033[31m'
cyan=$'\033[36m'
yellow=$'\033[33m'
gold=$'\033[38;2;230;200;0m'
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

format_cost() {
  local cost=$1
  awk "BEGIN { printf \"\\$%.2f\", $cost }"
}

# ── Line 1: pwd · git branch + status ────────────────────────────────────────
home_dir="$HOME"
display_path="${cwd/#$home_dir/~}"
[[ -z "$display_path" ]] && display_path="~"

git_part_ansi=""

if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if ! git --no-optional-locks -C "$cwd" diff --quiet 2>/dev/null \
     || ! git --no-optional-locks -C "$cwd" diff --cached --quiet 2>/dev/null; then
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

  ctx_part="${ctx_color}${ctx_circle}${reset} ${dim}≡${reset} ${ctx_color}${pct}%${reset}"
  if [[ -n "$line2_ansi" ]]; then
    line2_ansi+=" ${dim}·${reset} ${ctx_part}"
  else
    line2_ansi+="${ctx_part}"
  fi
fi

# ── Resolve OAuth token & cache paths ────────────────────────────────────────
# Token extracted once upfront and reused for profile + usage fetches.
# Cache key uses CLAUDE_CONFIG_DIR hash (or "default") to isolate accounts.
keychain_service="Claude Code-credentials"
cache_key="default"
if [[ -n "$CLAUDE_CONFIG_DIR" ]]; then
  cache_key=$(echo -n "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -c1-8)
  keychain_service="Claude Code-credentials-${cache_key}"
fi

token=""
if command -v security &>/dev/null; then
  blob=$(security find-generic-password -s "$keychain_service" -w 2>/dev/null)
  [[ -n "$blob" ]] && token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
fi

cache_file="/tmp/claude/statusline-usage-${cache_key}.json"
cache_max_age=60
mkdir -p /tmp/claude 2>/dev/null

# ── Fetch profile (cached indefinitely per account) ──────────────────────────
profile_cache="/tmp/claude/statusline-profile-${cache_key}.json"
org_name=""
org_type=""

if [[ -f "$profile_cache" ]]; then
  org_name=$(jq -r '.organization.name // empty' "$profile_cache" 2>/dev/null)
  org_type=$(jq -r '.organization.organization_type // empty' "$profile_cache" 2>/dev/null)
elif [[ -n "$token" && "$token" != "null" ]]; then
  profile_resp=$(curl -s --max-time 3 \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/profile" 2>/dev/null)
  if [[ -n "$profile_resp" ]] && echo "$profile_resp" | jq -e '.organization' &>/dev/null; then
    echo "$profile_resp" > "$profile_cache"
    org_name=$(echo "$profile_resp" | jq -r '.organization.name // empty')
    org_type=$(echo "$profile_resp" | jq -r '.organization.organization_type // empty')
  fi
fi

plan_display=""
if [[ -n "$org_type" ]]; then
  case "$org_type" in
    claude_team)       plan_display="Team" ;;
    claude_pro)        plan_display="Pro" ;;
    claude_enterprise) plan_display="Enterprise" ;;
    claude_max)        plan_display="Max" ;;
    *)                 plan_display="${org_type#claude_}" ;;
  esac
fi

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
  if [[ -n "$token" && "$token" != "null" ]]; then
    response=$(curl -s --max-time 3 \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if [[ -n "$response" ]] && echo "$response" | jq -e . &>/dev/null; then
      usage_data="$response"
      echo "$response" > "$cache_file"
    fi
  fi
  # Fall back to stale cache
  if [[ -z "$usage_data" && -f "$cache_file" ]]; then
    usage_data=$(<"$cache_file")
  fi
fi

# ── Usage lines ──────────────────────────────────────────────────────────────
usage_lines=()

if [[ -n "$usage_data" ]] && echo "$usage_data" | jq -e . &>/dev/null; then
  # ── Rate limits (subscription) ─────────────────────────────────────────────
  has_limits=false

  # 5-hour (session) limit
  if echo "$usage_data" | jq -e '.five_hour != null' &>/dev/null; then
    has_limits=true
    five_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')")
    five_col=$(color_for_pct "$five_pct")
    five_circle=$(circle_for_pct "$five_pct")

    line="${five_col}${five_circle}${reset} ${dim}session${reset} ${five_col}${five_pct}%${reset}"
    [[ -n "$five_reset" ]] && line+=" ${dim}⟳ ${five_reset}${reset}"
    usage_lines+=("$line")
  fi

  # 7-day (weekly) limit
  if echo "$usage_data" | jq -e '.seven_day != null' &>/dev/null; then
    seven_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    seven_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')")
    seven_col=$(color_for_pct "$seven_pct")
    seven_circle=$(circle_for_pct "$seven_pct")

    line="${seven_col}${seven_circle}${reset} ${dim}weekly${reset}  ${seven_col}${seven_pct}%${reset}"
    [[ -n "$seven_reset" ]] && line+=" ${dim}⟳ ${seven_reset}${reset}"
    usage_lines+=("$line")
  fi

  # 7-day Sonnet limit
  if echo "$usage_data" | jq -e '.seven_day_sonnet != null' &>/dev/null; then
    sonnet_pct=$(echo "$usage_data" | jq -r '.seven_day_sonnet.utilization // 0' | awk '{printf "%.0f", $1}')
    sonnet_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.seven_day_sonnet.resets_at // empty')")
    sonnet_col=$(color_for_pct "$sonnet_pct")
    sonnet_circle=$(circle_for_pct "$sonnet_pct")

    line="${sonnet_col}${sonnet_circle}${reset} ${dim}sonnet${reset}  ${sonnet_col}${sonnet_pct}%${reset}"
    [[ -n "$sonnet_reset" ]] && line+=" ${dim}⟳ ${sonnet_reset}${reset}"
    usage_lines+=("$line")
  fi

  # ── Extra usage / credits ──────────────────────────────────────────────────
  if echo "$usage_data" | jq -e '.extra_usage.is_enabled == true' &>/dev/null; then
    cost_parts=()

    # Session cost from statusline JSON
    if (( $(awk "BEGIN { print ($session_cost > 0) }") )); then
      cost_parts+=("${dim}session${reset} ${gold}$(format_cost "$session_cost")${reset}")
    fi

    # Total credits spent
    used_credits=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0')
    if (( $(awk "BEGIN { print ($used_credits > 0) }") )); then
      credits_display=$(awk "BEGIN { printf \"≈\\$%.2f\", $used_credits / 100 }")
      cost_parts+=("${dim}total${reset} ${gold}${credits_display}${reset}")
    fi

    # Utilization gauge (when monthly limit is set)
    extra_util=$(echo "$usage_data" | jq -r '.extra_usage.utilization // empty')
    if [[ -n "$extra_util" && "$extra_util" != "null" ]]; then
      extra_pct=$(awk "BEGIN { printf \"%.0f\", $extra_util }")
      extra_col=$(color_for_pct "$extra_pct")
      extra_circle=$(circle_for_pct "$extra_pct")
      cost_parts+=("${extra_col}${extra_circle} ${extra_pct}%${reset}")
    fi

    if [[ ${#cost_parts[@]} -gt 0 ]]; then
      cost_line="${gold}⬡${reset} ${cost_parts[1]}"
      for part in "${cost_parts[@]:1}"; do
        cost_line+=" ${dim}·${reset} ${part}"
      done
      usage_lines+=("$cost_line")
    fi
  fi
fi

# ── Fallback: API key user (no OAuth data) — show session cost only ──────────
if [[ ${#usage_lines[@]} -eq 0 ]] && (( $(awk "BEGIN { print ($session_cost > 0) }") )); then
  usage_lines+=("${gold}⬡${reset} ${dim}session${reset} ${gold}$(format_cost "$session_cost")${reset}")
fi

# ── Render ────────────────────────────────────────────────────────────────────
line1_ansi="${blue}${display_path}${reset}${git_part_ansi}"

printf "%b" "$line1_ansi"

if [[ -n "$plan_display" ]]; then
  plan_line=""
  [[ -n "$org_name" ]] && plan_line+="${dim}${org_name}${reset} ${dim}·${reset} "
  plan_line+="${dim}${plan_display}${reset}"
  printf "\n%b" "$plan_line"
fi

[[ -n "$line2_ansi" ]] && printf "\n%b" "$line2_ansi"
for uline in "${usage_lines[@]}"; do
  printf "\n%b" "$uline"
done
