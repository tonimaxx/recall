---
description: Manually capture a recall checkpoint mid-session. Use when finishing a logical chunk of work and you want it logged before continuing or before the SessionEnd hook fires automatically.
---

# recall · checkpoint

You are writing a manual entry to `.claude/status.md`. Do exactly:

1. Verify `.claude/recall.json` exists. If not, print: "recall is not enabled here. Run `/recall:init` first." Stop.
2. Determine the project basename from `CLAUDE_PROJECT_DIR` or `$PWD`.
3. Compose an entry with this structure (newest entries go at the top of `status.md`, immediately after the header):

```markdown
## YYYY-MM-DD HH:MM TZ — <project> _(via /recall:checkpoint)_

- **What just happened:** <one tight sentence — what was decided, fixed, or built in the last few turns>
- **State:** <git branch + short hash + clean/dirty if you can read it; otherwise omit>
- **Open thread:** <single open question or next step; "—" if there isn't one>
- **Files touched:** <inline list of paths, or "—">
- **Note from user (if any):** <verbatim text from $ARGUMENTS, redacted of secrets, else omit>
```

4. Insert this entry **after the `> Append-only log…` blockquote header** in `.claude/status.md`. Do not overwrite earlier entries.
5. After writing, confirm with one line: "✓ checkpoint saved." Then stop.

Constraints:
- Never include API keys, bearer tokens, or anything matching `recall.json`'s `redact_patterns`. If unsure, redact.
- If a `## ` entry with the same minute already exists, merge into it rather than creating a duplicate.
- Keep the entry under ~200 words. The point is signal, not transcript.
- If `$ARGUMENTS` is empty, infer the entry content from recent context. If `$ARGUMENTS` is provided, treat it as the user's note for the entry.
