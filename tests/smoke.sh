#!/usr/bin/env bash
# recall · smoke test
# Exercises the lib + hook pipeline against a synthetic transcript.
# No network, no real Claude session needed.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"

# Build a throwaway "project" with recall enabled.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.claude"
cp examples/recall.json "$WORK/.claude/recall.json"
export CLAUDE_PROJECT_DIR="$WORK"

cd "$WORK" && git init -q && git commit -q --allow-empty -m "init" && cd "$ROOT"

# Synthesize hook input pointing at the fixture transcript.
fixture="$ROOT/tests/fixtures/transcript.jsonl"
input=$(jq -n \
  --arg t "$fixture" \
  --arg c "$WORK" \
  --arg s "smoke-$(date +%s)" \
  '{transcript_path:$t, cwd:$c, session_id:$s, hook_event_name:"SessionEnd"}')

echo "── 1. SessionEnd writes status.md ──"
printf '%s' "$input" | bash hooks/session-end-write.sh
test -f "$WORK/.claude/status.md" || { echo "FAIL: status.md not created"; exit 1; }

if ! grep -q '## ' "$WORK/.claude/status.md"; then
  echo "FAIL: no ## entry"; cat "$WORK/.claude/status.md"; exit 1
fi
echo "  ok"

echo "── 2. secrets are redacted ──"
if grep -q 'sk-abcd1234' "$WORK/.claude/status.md"; then
  echo "FAIL: API key leaked into status.md"; exit 1
fi
echo "  ok"

echo "── 3. SessionStart banner emits JSON additionalContext ──"
banner_out=$(printf '%s' "$input" | bash hooks/session-start-banner.sh)
echo "$banner_out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
echo "  ok"

echo "── 4. Stop hook is debounced ──"
input_stop=$(jq -n \
  --arg t "$fixture" --arg c "$WORK" --arg s "smoke-$(date +%s)" \
  '{transcript_path:$t, cwd:$c, session_id:$s, hook_event_name:"Stop"}')
printf '%s' "$input_stop" | bash hooks/stop-debounce.sh
count1=$(grep -c '^## ' "$WORK/.claude/status.md")
printf '%s' "$input_stop" | bash hooks/stop-debounce.sh
count2=$(grep -c '^## ' "$WORK/.claude/status.md")
test "$count1" = "$count2" || { echo "FAIL: stop hook ran twice within debounce window"; exit 1; }
echo "  ok (count stable at $count1)"

echo "── 5. inert mode when project not opted in ──"
WORK2=$(mktemp -d)
trap 'rm -rf "$WORK" "$WORK2"' EXIT
input2=$(jq -n --arg t "$fixture" --arg c "$WORK2" --arg s "x" \
  '{transcript_path:$t, cwd:$c, session_id:$s, hook_event_name:"SessionEnd"}')
printf '%s' "$input2" | bash hooks/session-end-write.sh
test ! -f "$WORK2/.claude/status.md" || { echo "FAIL: wrote status.md to non-opted-in project"; exit 1; }
echo "  ok (no files touched)"

echo
echo "all smoke checks passed."
