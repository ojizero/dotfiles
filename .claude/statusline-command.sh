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

  local today=$(date +%Y-%m-%d)
  local reset_day=$(date -j -r "$epoch" +"%Y-%m-%d" 2>/dev/null)
  local time_str=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
  if [[ "$reset_day" != "$today" ]]; then
    local day_str=$(date -j -r "$epoch" +"%a" 2>/dev/null)
    echo "${day_str} ${time_str}"
  else
    echo "$time_str"
  fi
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

# Derive a token-scoped suffix so that switching accounts (same CLAUDE_CONFIG_DIR,
# different token) never serves a stale profile or usage cache from the old account.
token_key="$cache_key"
if [[ -n "$token" && "$token" != "null" ]]; then
  token_key="${cache_key}-$(echo -n "$token" | shasum -a 256 | cut -c1-8)"
fi

cache_file="/tmp/claude/statusline-usage-${token_key}.json"
cache_max_age=60
mkdir -p /tmp/claude 2>/dev/null

# ── Fetch profile (cached indefinitely per token identity) ────────────────────
profile_cache="/tmp/claude/statusline-profile-${token_key}.json"
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
    echo "$profile_resp" > "${profile_cache}.$$" && mv -f "${profile_cache}.$$" "$profile_cache"
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
    # Only accept responses shaped like usage data — API error bodies (e.g.
    # {"error": {"type": "rate_limit_error"}}) are valid JSON and must not
    # overwrite a good cache or mask the stale-cache fallback below.
    if [[ -n "$response" ]] && echo "$response" | jq -e '.limits or .five_hour' &>/dev/null; then
      usage_data="$response"
      echo "$response" > "${cache_file}.$$" && mv -f "${cache_file}.$$" "$cache_file"
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
  # Dynamically enumerate rate-limit buckets so new per-model weekly buckets
  # (opus, fable, future models, ...) show up automatically without code changes.
  #
  # Prefer the newer `.limits` array — it is the source that drives the
  # claude.ai settings page and carries per-model "weekly_scoped" buckets like
  # Fable (scope.model.display_name). Fall back to the legacy top-level keys
  # (five_hour / seven_day / seven_day_*) when `.limits` is absent.
  #
  # Each bucket is emitted as a `label<TAB>percent<TAB>resets_at` row. Labels:
  #   session · weekly · <model> (e.g. sonnet, opus, fable), lower-cased.
  bucket_tsv=$(echo "$usage_data" | jq -r '
    if (.limits | type) == "array" and (.limits | length) > 0 then
      .limits[]
      | select(type == "object" and has("percent"))
      | [ (if   .kind == "session"       then "session"
           elif .kind == "weekly_all"    then "weekly"
           elif .kind == "weekly_scoped" then ((.scope.model.display_name // .kind) | ascii_downcase)
           else .kind end),
          (.percent // 0 | tostring),
          (.resets_at // "") ]
      | @tsv
    else
      to_entries
      | map(select(.value | type == "object" and has("utilization")))
      | map(select(.key == "five_hour" or (.key | startswith("seven_day"))))
      | sort_by(if .key == "five_hour" then "0" elif .key == "seven_day" then "1" else "2" + .key end)
      | .[]
      | [ (if   .key == "five_hour"                then "session"
           elif .key == "seven_day"                then "weekly"
           elif (.key | startswith("seven_day_"))  then .key[10:]
           else .key end),
          (.value.utilization // 0 | tostring),
          (.value.resets_at // "") ]
      | @tsv
    end
  ')

  # Parse rows into parallel arrays; compute common label width for alignment.
  labels=(); pcts=(); resets=()
  while IFS=$'\t' read -r b_label b_pct b_reset; do
    [[ -z "$b_label" ]] && continue
    labels+=("$b_label"); pcts+=("$b_pct"); resets+=("$b_reset")
  done <<< "$bucket_tsv"

  label_width=0
  for b_label in "${labels[@]}"; do
    [[ ${#b_label} -gt $label_width ]] && label_width=${#b_label}
  done

  for (( i = 1; i <= ${#labels[@]}; i++ )); do
    padded_label="${(r:label_width:)labels[$i]}"

    pct=$(printf '%.0f' "${pcts[$i]}" 2>/dev/null); [[ -z "$pct" ]] && pct=0
    bucket_reset=$(format_reset_time "${resets[$i]}")
    col=$(color_for_pct "$pct")
    circle=$(circle_for_pct "$pct")

    line="${col}${circle}${reset} ${dim}${padded_label}${reset} ${col}$(printf '%3s' "$pct")%${reset}"
    [[ -n "$bucket_reset" ]] && line+=" ${dim}⟳ ${bucket_reset}${reset}"
    usage_lines+=("$line")
  done

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

# ── Fallback: API key user (no OAuth token at all) — show session cost only ───
# Only show session cost when there is no OAuth token (i.e., not a subscription
# user). If a token exists but produced no usage lines, the user is a subscription
# user whose rate limits just happen to be empty — don't show cost there.
if [[ ${#usage_lines[@]} -eq 0 && -z "$token" ]] && (( $(awk "BEGIN { print ($session_cost > 0) }") )); then
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
