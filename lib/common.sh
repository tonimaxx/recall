#!/usr/bin/env bash
# recall · shared shell library
# Sourced by every hook. Keep it dependency-light: only `jq` is required.

set -euo pipefail

# ─── logging ─────────────────────────────────────────────────────────────────
recall::log() {
  [[ "${RECALL_DEBUG:-0}" == "1" ]] || return 0
  printf '[recall] %s\n' "$*" >&2
}

recall::die() {
  printf '[recall:error] %s\n' "$*" >&2
  exit 1
}

# ─── enablement ──────────────────────────────────────────────────────────────
# A project opts in by creating .claude/recall.json.
# Hooks short-circuit when the marker is absent.
recall::is_enabled() {
  local cwd="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  [[ -f "$cwd/.claude/recall.json" ]]
}

# ─── config (project-level overrides) ────────────────────────────────────────
recall::config_get() {
  local key="$1" default="$2"
  local cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  local cfg="$cwd/.claude/recall.json"
  [[ -f "$cfg" ]] || { printf '%s' "$default"; return; }
  local val
  val=$(jq -r --arg k "$key" --arg d "$default" '.[$k] // $d' "$cfg" 2>/dev/null) || val="$default"
  printf '%s' "$val"
}

recall::config_array() {
  local key="$1"
  local cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  local cfg="$cwd/.claude/recall.json"
  [[ -f "$cfg" ]] || return 0
  jq -r --arg k "$key" '.[$k][]?' "$cfg" 2>/dev/null || true
}

# ─── paths ───────────────────────────────────────────────────────────────────
recall::status_file() {
  printf '%s/.claude/status.md' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

recall::archive_file() {
  printf '%s/.claude/status-archive.md' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

recall::stop_state_file() {
  printf '%s/.claude/.recall-last-stop' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# ─── transcript reading ──────────────────────────────────────────────────────
# Hook stdin (JSON) → fields. Reads transcript and returns up to N tail events.
recall::read_hook_input() {
  cat
}

# Get the transcript path from the hook input JSON.
recall::transcript_path() {
  local input="$1"
  printf '%s' "$input" | jq -r '.transcript_path // empty'
}

recall::session_id() {
  local input="$1"
  printf '%s' "$input" | jq -r '.session_id // empty'
}

recall::cwd_from_input() {
  local input="$1"
  printf '%s' "$input" | jq -r '.cwd // empty'
}

# Pull recent user/assistant turns from the JSONL transcript.
# Args: transcript_path, max_turns
recall::tail_turns() {
  local path="$1" max="${2:-6}"
  [[ -f "$path" ]] || return 0
  # Each line is a JSON event. We extract role + first 400 chars of content.
  tail -n 400 "$path" \
    | jq -r --argjson n "$max" '
        select(.type == "user" or .type == "assistant")
        | {role: .type, content: (.message.content // .content // "")}
        | select(.content != "")
        | "\(.role): \((.content|tostring)[0:400] | gsub("\n";" "))"
      ' 2>/dev/null \
    | tail -n "$((max * 2))" || true
}

# ─── secret redaction ────────────────────────────────────────────────────────
# Replace anything matching configured patterns with [REDACTED].
# Defaults cover common API key envs and Bearer tokens.
recall::redact() {
  local text="$1"
  local default_pats=(
    'OLLAMA_API_KEY' 'OPENAI_API_KEY' 'ANTHROPIC_API_KEY'
    'BOT_TOKEN' 'TELEGRAM_TOKEN' 'NOTIFY_BOT_TOKEN'
    'AWS_SECRET_ACCESS_KEY' 'AWS_ACCESS_KEY_ID'
    'GH_TOKEN' 'GITHUB_TOKEN'
  )
  local extra
  extra=$(recall::config_array 'redact_patterns' || true)

  local pats=("${default_pats[@]}")
  if [[ -n "$extra" ]]; then
    while IFS= read -r p; do [[ -n "$p" ]] && pats+=("$p"); done <<<"$extra"
  fi

  local out="$text"
  # Pattern 1: NAME=<value> or NAME: <value> or "NAME": "<value>"
  for p in "${pats[@]}"; do
    out=$(printf '%s' "$out" \
      | sed -E "s/(${p})[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9._\\-]+['\"]?/\\1=[REDACTED]/g")
  done
  # Pattern 2: Bearer / sk- / ghp_ tokens regardless of name.
  out=$(printf '%s' "$out" \
    | sed -E 's/Bearer[[:space:]]+[A-Za-z0-9._\-]+/Bearer [REDACTED]/g' \
    | sed -E 's/(sk-|ghp_|github_pat_)[A-Za-z0-9_\-]{16,}/[REDACTED]/g')
  printf '%s' "$out"
}

# ─── git state snapshot ──────────────────────────────────────────────────────
recall::git_state() {
  local cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  [[ "$(recall::config_get 'include_git_state' 'true')" == "true" ]] || return 0
  ( cd "$cwd" && git rev-parse --git-dir >/dev/null 2>&1 ) || return 0

  local branch hash dirty
  branch=$(cd "$cwd" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
  hash=$(cd "$cwd" && git rev-parse --short HEAD 2>/dev/null || echo '?')
  dirty=$(cd "$cwd" && [[ -z "$(git status --porcelain 2>/dev/null)" ]] && echo 'clean' || echo 'dirty')
  printf 'git: %s @ %s (%s)' "$branch" "$hash" "$dirty"
}

# ─── subagent file integration ───────────────────────────────────────────────
# Read recent state from configured subagent state files, append to entry.
recall::subagent_snapshot() {
  local cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  local files
  files=$(recall::config_array 'include_subagent_files' || true)
  [[ -n "$files" ]] || return 0

  local out=""
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    local path="$cwd/$f"
    [[ -f "$path" ]] || continue
    local snippet
    snippet=$(tail -n 8 "$path" 2>/dev/null | sed 's/^/    /')
    [[ -z "$snippet" ]] && continue
    out+=$'\n'"  - **$f** (last 8 lines):"$'\n'"$snippet"
  done <<<"$files"

  printf '%s' "$out"
}

# ─── status.md append + cap ──────────────────────────────────────────────────
recall::append_entry() {
  local entry="$1"
  local file project
  file="$(recall::status_file)"
  project=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")
  mkdir -p "$(dirname "$file")"

  if [[ ! -f "$file" ]]; then
    cat >"$file" <<EOF
# Session log — $project

> Append-only log written by **recall**. Newest entries at the top.

EOF
  fi

  # Pass entry via env to avoid shell-quoting newlines through awk -v.
  local entry_tmp tmp
  entry_tmp=$(mktemp)
  printf '%s' "$entry" >"$entry_tmp"
  tmp=$(mktemp)
  python3 - "$file" "$entry_tmp" "$tmp" <<'PY'
import sys, pathlib
src = pathlib.Path(sys.argv[1])
entry = pathlib.Path(sys.argv[2]).read_text()
out = pathlib.Path(sys.argv[3])

text = src.read_text()
lines = text.splitlines(keepends=True)

# Find the blockquote line and the next blank line; insert entry after that.
inserted = False
result = []
i = 0
while i < len(lines):
    result.append(lines[i])
    if not inserted and lines[i].startswith('> Append-only log'):
        # Skip a following blank line if present, then insert.
        if i + 1 < len(lines) and lines[i+1].strip() == '':
            result.append(lines[i+1])
            i += 1
        result.append('\n')
        result.append(entry if entry.endswith('\n') else entry + '\n')
        inserted = True
    i += 1

if not inserted:
    # Fallback: prepend after first line.
    result = lines[:1] + ['\n', entry + '\n'] + lines[1:]

out.write_text(''.join(result))
PY
  mv "$tmp" "$file"
  rm -f "$entry_tmp"

  recall::cap_entries
}

# Trim status.md to max_entries; older entries spill into status-archive.md.
recall::cap_entries() {
  local max
  max=$(recall::config_get 'max_entries' '20')
  [[ "$max" =~ ^[0-9]+$ ]] || max=20

  local file archive
  file="$(recall::status_file)"
  archive="$(recall::archive_file)"
  [[ -f "$file" ]] || return 0

  # Count "## " H2 entries.
  local count
  count=$(grep -c '^## ' "$file" || true)
  (( count > max )) || return 0

  # Split: keep top `max`, archive the rest.
  python3 - "$file" "$archive" "$max" <<'PY' || true
import sys, pathlib
src = pathlib.Path(sys.argv[1])
arc = pathlib.Path(sys.argv[2])
keep = int(sys.argv[3])

text = src.read_text()
lines = text.splitlines(keepends=True)
header_end = 0
for i, l in enumerate(lines):
    if l.startswith('## '):
        header_end = i
        break

header = ''.join(lines[:header_end])
body = ''.join(lines[header_end:])

# Split body into chunks at each '## '
chunks = []
buf = []
for l in body.splitlines(keepends=True):
    if l.startswith('## ') and buf:
        chunks.append(''.join(buf)); buf = []
    buf.append(l)
if buf:
    chunks.append(''.join(buf))

kept = chunks[:keep]
archived = chunks[keep:]

src.write_text(header + ''.join(kept))
if archived:
    if arc.exists():
        prior = arc.read_text()
    else:
        prior = '# Archived session log\n\n'
    arc.write_text(prior + ''.join(archived))
PY
}

# ─── stop debounce ───────────────────────────────────────────────────────────
recall::should_run_stop() {
  local debounce_min
  debounce_min=$(recall::config_get 'stop_debounce_minutes' '10')
  [[ "$debounce_min" =~ ^[0-9]+$ ]] || debounce_min=10

  local state
  state="$(recall::stop_state_file)"
  if [[ -f "$state" ]]; then
    local last now diff
    last=$(cat "$state" 2>/dev/null || echo 0)
    now=$(date +%s)
    diff=$(( now - last ))
    if (( diff < debounce_min * 60 )); then
      recall::log "stop debounced (${diff}s < ${debounce_min}min)"
      return 1
    fi
  fi
  mkdir -p "$(dirname "$state")"
  date +%s >"$state"
  return 0
}

# ─── entry composer ──────────────────────────────────────────────────────────
recall::compose_entry() {
  local trigger="$1" input="$2"
  local now project transcript turns redacted git_line subagent

  now=$(date +'%Y-%m-%d %H:%M %Z')
  project=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")
  transcript=$(recall::transcript_path "$input")
  git_line=$(recall::git_state || true)
  subagent=$(recall::subagent_snapshot || true)

  turns=""
  if [[ -n "$transcript" ]]; then
    turns=$(recall::tail_turns "$transcript" 4 || true)
    turns=$(recall::redact "$turns")
  fi

  {
    printf '## %s — %s _(via %s)_\n\n' "$now" "$project" "$trigger"
    [[ -n "$git_line" ]] && printf -- '- %s\n' "$git_line"
    if [[ -n "$turns" ]]; then
      printf -- '- **Recent turns:**\n'
      printf '%s\n' "$turns" | sed 's/^/    /'
    fi
    [[ -n "$subagent" ]] && printf -- '- **Subagent state:**%s\n' "$subagent"
    printf '\n'
  }
}
