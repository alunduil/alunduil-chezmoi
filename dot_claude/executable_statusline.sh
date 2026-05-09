#!/usr/bin/env bash
# Claude Code status line: model · context% · cost · 5h limit · 7d limit.
# Reads stdin JSON per https://code.claude.com/docs/en/statusline.md.
# rate_limits appears only on Pro/Max plans and only after the first API
# response in the session — the 5h and 7d segments stay hidden until then.

set -euo pipefail

input="$(cat)"

model=$(jq -r '.model.display_name // .model.id // "?"' <<<"$input")
ctx=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
cost=$(jq -r '.cost.total_cost_usd // empty' <<<"$input")
five_pct=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
five_reset=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
seven_pct=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
seven_reset=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<<"$input")

# Drop "Claude " so the family + version remains unambiguous on a narrow
# pair pane without abbreviating to e.g. "O4.7" (reads as "0-4.7").
model=${model#Claude }

amber=$'\033[33m'
red=$'\033[31m'
clear=$'\033[0m'

# Round to match the displayed integer so threshold and display agree on
# the boundary (e.g. 74.6% reads as "75%" and trips the amber threshold).
pct_color() {
  local pct
  pct=$(printf '%.0f' "$1")
  if [ "$pct" -ge 90 ]; then
    printf '%s' "$red"
  elif [ "$pct" -ge 75 ]; then
    printf '%s' "$amber"
  fi
}

paint() {
  local color=$1 text=$2
  printf '%s%s%s' "$color" "$text" "${color:+$clear}"
}

parts=("$model")
[ -n "$ctx" ]  && parts+=("$(paint "$(pct_color "$ctx")" "$(printf '%.0f%%' "$ctx")")")
[ -n "$cost" ] && parts+=("$(printf '$%.2f' "$cost")")

if [ -n "$five_pct" ] && [ -n "$five_reset" ]; then
  parts+=("$(paint "$(pct_color "$five_pct")" "$(printf '5h %.0f%% %s' "$five_pct" "$(date -d "@$five_reset" +%H:%M)")")")
fi
if [ -n "$seven_pct" ] && [ -n "$seven_reset" ]; then
  parts+=("$(paint "$(pct_color "$seven_pct")" "$(printf '7d %.0f%% %s' "$seven_pct" "$(date -d "@$seven_reset" +'%a %H:%M')")")")
fi

out=""
for p in "${parts[@]}"; do out="${out:+$out · }$p"; done
printf '%s\n' "$out"
