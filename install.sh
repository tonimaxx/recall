#!/usr/bin/env bash
# recall · one-line installer
#
# Adds the recall marketplace + plugin to Claude Code's user-level settings,
# so the next session has /recall:init, /recall:resume, /recall:checkpoint
# available without manual /plugin install.
#
#   curl -fsSL https://raw.githubusercontent.com/tonimaxx/recall/main/install.sh | bash
#
# Or run locally:
#
#   bash install.sh

set -euo pipefail

MARKETPLACE_NAME="recall"
PLUGIN_KEY="recall@recall"
REPO="tonimaxx/recall"

settings_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_file="$settings_dir/settings.json"
mkdir -p "$settings_dir"

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ jq is required (brew install jq)" >&2
  exit 1
fi

if [[ ! -f "$settings_file" ]]; then
  printf '{}\n' >"$settings_file"
fi

# Backup once per day so reruns don't churn through copies.
backup="$settings_file.bak.$(date +%Y%m%d)"
[[ -f "$backup" ]] || cp "$settings_file" "$backup"

tmp=$(mktemp)
jq --arg name "$MARKETPLACE_NAME" \
   --arg repo "$REPO" \
   --arg key "$PLUGIN_KEY" \
   '
   .extraKnownMarketplaces //= {}
   | .extraKnownMarketplaces[$name] = {
       "source": {"source": "github", "repo": $repo}
     }
   | .enabledPlugins //= {}
   | .enabledPlugins[$key] = true
   ' "$settings_file" >"$tmp"

mv "$tmp" "$settings_file"

# Clear plugin cache so a stale entry doesn't suppress the new install.
rm -rf "$settings_dir/plugins/cache"

cat <<EOF

✓ recall installed.
  marketplace: $MARKETPLACE_NAME (github: $REPO)
  plugin:      $PLUGIN_KEY
  settings:    $settings_file
  backup:      $backup

Next:
  1. Restart Claude Code (or run /reload-plugins in an active session).
  2. cd into the project you want to enable, then run /recall:init.
  3. Type /recall:resume to load prior context, /recall:checkpoint to save manually.

Override fresh-session for one invocation:  CLAUDE_NO_RESUME=1 claude
Disable globally:                            edit $settings_file and set
                                             enabledPlugins["$PLUGIN_KEY"] = false
EOF
