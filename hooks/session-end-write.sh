#!/usr/bin/env bash
# recall · SessionEnd hook — append a structured entry to .claude/status.md.
# Inert if the project hasn't opted in (no .claude/recall.json).

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$PLUGIN_ROOT/lib/common.sh"

# Honor explicit fresh-session requests by suppressing the writer too.
[[ "${CLAUDE_NO_RESUME:-0}" == "1" ]] && exit 0

input=$(recall::read_hook_input)
cwd_in=$(recall::cwd_from_input "$input")
[[ -n "$cwd_in" ]] && export CLAUDE_PROJECT_DIR="$cwd_in"

recall::is_enabled || exit 0

entry=$(recall::compose_entry "SessionEnd" "$input")
recall::append_entry "$entry"
recall::log "wrote entry to $(recall::status_file)"
