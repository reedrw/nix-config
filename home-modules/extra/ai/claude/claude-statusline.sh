#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq git
input=$(cat)

reset=$'\033[0m'
bold=$'\033[1m'
dim=$'\033[2m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'
cyan=$'\033[36m'
purple=$'\033[35m'
blue=$'\033[34m'
git_branch_icon=$'\xee\x9c\xa5'

# green < 50%, yellow < 75%, red >= 75%
pct_color() {
  local pct="${1:-0}"
  if   [ "$pct" -lt 50 ]; then printf '%s' "$green"
  elif [ "$pct" -lt 75 ]; then printf '%s' "$yellow"
  else                          printf '%s' "$red"
  fi
}

bar() {
  local pct="${1:-0}"
  local width=10
  local filled=$(( (pct * width + 50) / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$(( width - filled ))
  printf '%s' "$(pct_color "$pct")"
  printf '%.0s█' $(seq 1 "$filled") 2>/dev/null || true
  printf '%s' "$dim"
  printf '%.0s░' $(seq 1 "$empty")  2>/dev/null || true
  printf '%s' "$reset"
}

# Format a unix timestamp as a dimmed "↺Xh Ym" or "↺Xm" suffix
reset_label() {
  local ts="$1"
  [ -z "$ts" ] && return
  local now diff
  now=$(date +%s)
  diff=$(( ts - now ))
  [ "$diff" -le 0 ] && return
  if   [ "$diff" -ge 3600 ]; then printf ' %s%dh%02dm%s' "$dim" $(( diff / 3600 )) $(( (diff % 3600) / 60 )) "$reset"
  elif [ "$diff" -ge 60 ];   then printf ' %s%dm%s'       "$dim" $(( diff / 60 ))                              "$reset"
  else                            printf ' %s%ds%s'        "$dim" "$diff"                                       "$reset"
  fi
}

effort_style() {
  local level="$1"
  case "$level" in
    low)    printf '%s%s%s' "${bold}${yellow}" "$level"   "${reset}" ;;
    medium) printf '%s%s%s' "${bold}${green}"  "$level"   "${reset}" ;;
    high)   printf '%s%s%s' "${bold}${blue}"   "$level"   "${reset}" ;;
    xhigh)  printf '%s%s%s' "${bold}${purple}" "$level"   "${reset}" ;;
    max)
      local label="maximum"
      local colors=("${red}" "${yellow}" "${green}" "${cyan}" "${blue}" "${purple}")
      local out="" i=0
      while [ "$i" -lt "${#label}" ]; do
        out="${out}${bold}${colors[$(( i % 6 ))]}${label:$i:1}"
        i=$(( i + 1 ))
      done
      printf '%s%s' "$out" "${reset}"
      ;;
    *) printf '%s%s%s' "${dim}" "$level" "${reset}" ;;
  esac
}

meter() {
  local label="$1" pct="$2" reset_ts="${3:-}"
  local pct_int
  pct_int=$(printf '%.0f' "$pct")
  printf '%s%s%s %s %s%s%d%%%s%s' \
    "$bold$cyan" "$label" "$reset" \
    "$(bar "$pct_int")" \
    "$(pct_color "$pct_int")" "$bold" "$pct_int" "$reset" \
    "$(reset_label "$reset_ts")"
}

model=$(echo "$input"  | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input"   | jq -r '.cwd // empty')
repo=$(echo "$input"  | jq -r '.workspace.repo.name // empty')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
advisor=$(jq -r '.advisorModel // empty' "$HOME/.claude/settings.json" 2>/dev/null || true)
ctx=$(echo "$input"     | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input"    | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_ts=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_ts=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

model_part=""
[ -n "$model"   ] && model_part="${bold}${purple}◆ ${model}${reset}"
[ -n "$effort"  ] && model_part="${model_part} $(effort_style "$effort")"
if [ -n "$advisor" ] && ! echo "$model" | grep -qi "opus"; then
  model_part="${model_part} ${dim}via ${advisor}${reset}"
fi

repo_part=""
[ -n "$repo"   ] && repo_part="${bold}${yellow}${repo}${reset}"
[ -n "$branch" ] && repo_part="${repo_part} ${yellow}${git_branch_icon} ${branch}${reset}"

parts=()
[ -n "$model_part" ] && parts+=("$model_part")
[ -n "$ctx"        ] && parts+=("$(meter "📁 ctx"  "$ctx")")
[ -n "$five"       ] && parts+=("$(meter "⌚ 5h" "$five" "$five_ts")")
[ -n "$week"       ] && parts+=("$(meter "📅 7d" "$week" "$week_ts")")
[ -n "$repo_part"  ] && parts+=("$repo_part")

if [ "${#parts[@]}" -gt 0 ]; then
  out=""
  sep="${dim}  |  ${reset}"
  for part in "${parts[@]}"; do
    [ -n "$out" ] && out="${out}${sep}"
    out="${out}${part}"
  done
  printf '%s\n' "$out"
fi
