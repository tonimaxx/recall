#!/usr/bin/env bash
# recall · uninstall
# Removes recall from user settings and clears the plugin cache.
# Does NOT touch any project's .claude/recall.json or status.md.

set -euo pipefail

MARKETPLACE_NAME="recall"
PLUGIN_KEY="recall@recall"

settings_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_file="$settings_dir/settings.json"

if [[ ! -f "$settings_file" ]]; then
  echo "no settings.json found at $settings_file — nothing to do."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ jq is required" >&2
  exit 1
fi

backup="$settings_file.bak.$(date +%Y%m%d-%H%M%S)"
cp "$settings_file" "$backup"

tmp=$(mktemp)
jq --arg name "$MARKETPLACE_NAME" --arg key "$PLUGIN_KEY" '
  if .extraKnownMarketplaces then .extraKnownMarketplaces |= del(.[$name]) else . end
  | if .enabledPlugins then .enabledPlugins |= del(.[$key]) else . end
' "$settings_file" >"$tmp"

mv "$tmp" "$settings_file"
rm -rf "$settings_dir/plugins/cache"

cat <<EOF
✓ recall uninstalled from user settings.
  settings: $settings_file
  backup:   $backup

Per-project state (.claude/recall.json, .claude/status.md) is untouched.
Delete those by hand if you also want to remove project-level traces.
EOF
