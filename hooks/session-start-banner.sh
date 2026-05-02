#!/usr/bin/env bash
# recall · SessionStart hook — inject a tiny one-line banner.
# Reads the most recent entry from .claude/status.md and prints a structured
# JSON output that Claude Code treats as additionalContext.
#
# Suppression:
#   - CLAUDE_NO_RESUME=1                 → skip injection (per-invocation)
#   - .claude/recall.json missing        → plugin inert in this project

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$PLUGIN_ROOT/lib/common.sh"

[[ "${CLAUDE_NO_RESUME:-0}" == "1" ]] && exit 0

input=$(recall::read_hook_input)
cwd_in=$(recall::cwd_from_input "$input")
[[ -n "$cwd_in" ]] && export CLAUDE_PROJECT_DIR="$cwd_in"

recall::is_enabled || exit 0

status_file="$(recall::status_file)"
[[ -f "$status_file" ]] || exit 0

# Grab the first ## entry (newest).
banner=$(awk '
  /^## / { if (found++) exit; sub(/^## /, ""); print; next }
' "$status_file")

[[ -n "$banner" ]] || exit 0

# Trim to roughly banner_max_tokens (rough byte cap; 1 token ≈ 4 bytes).
max_tokens=$(recall::config_get 'banner_max_tokens' '60')
[[ "$max_tokens" =~ ^[0-9]+$ ]] || max_tokens=60
max_bytes=$(( max_tokens * 4 ))
if (( ${#banner} > max_bytes )); then
  banner="${banner:0:$max_bytes}…"
fi

context=$(printf 'recall · last session: %s\n(type /recall:resume to load full context, or set CLAUDE_NO_RESUME=1 for a fresh session)' "$banner")

# Structured stdout: Claude Code injects this as additionalContext.
jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
