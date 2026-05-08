#!/usr/bin/env bash
# Claude Code status line: model · context% · session cost.
# Reads stdin JSON per https://code.claude.com/docs/en/statusline.md.

set -euo pipefail

input="$(cat)"

model=$(jq -r '.model.display_name // .model.id // "?"' <<<"$input")
ctx=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
cost=$(jq -r '.cost.total_cost_usd // empty' <<<"$input")

# Shorten labels for narrow zellij pair panes.
case "$model" in
  *"Opus 4.7"*)   model="O4.7" ;;
  *"Opus 4.6"*)   model="O4.6" ;;
  *"Sonnet 4.6"*) model="S4.6" ;;
  *"Sonnet 4.5"*) model="S4.5" ;;
  *"Haiku 4.5"*)  model="H4.5" ;;
esac

parts=("$model")
[ -n "$ctx" ]  && parts+=("$(printf '%.0f%%' "$ctx")")
[ -n "$cost" ] && parts+=("$(printf '$%.2f' "$cost")")

out=""
for p in "${parts[@]}"; do out="${out:+$out · }$p"; done
printf '%s\n' "$out"
