#!/usr/bin/env bash
# recall · Stop hook (fallback) — debounced status writer.
# SessionEnd doesn't always fire (force-quit, network drop, OOM). This hook runs
# on every Stop event but writes at most once per `stop_debounce_minutes`,
# guaranteeing the log isn't empty for sessions that exit abnormally.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/common.sh
source "$PLUGIN_ROOT/lib/common.sh"

[[ "${CLAUDE_NO_RESUME:-0}" == "1" ]] && exit 0

input=$(recall::read_hook_input)
cwd_in=$(recall::cwd_from_input "$input")
[[ -n "$cwd_in" ]] && export CLAUDE_PROJECT_DIR="$cwd_in"

recall::is_enabled || exit 0
recall::should_run_stop || exit 0

entry=$(recall::compose_entry "Stop (debounced)" "$input")
recall::append_entry "$entry"
recall::log "stop fallback wrote entry"
