---
description: Opt this project into recall. Creates .claude/recall.json with default config and an empty status.md so SessionEnd starts logging.
disable-model-invocation: true
---

# recall · init

You are activating recall for the **current project** ($CLAUDE_PROJECT_DIR or the working directory). Do exactly the following, in order:

1. Verify the project root has a `.claude/` directory; create it if missing.
2. Check whether `.claude/recall.json` already exists.
   - If it does, print: "recall is already enabled in this project — config at `.claude/recall.json`. Edit it directly to change behavior." Then stop.
3. Otherwise, write `.claude/recall.json` with this exact content:

```json
{
  "max_entries": 20,
  "banner_max_tokens": 60,
  "stop_debounce_minutes": 10,
  "include_git_state": true,
  "include_subagent_files": ["status.md", "task.md", "output.md"],
  "redact_patterns": [
    "OLLAMA_API_KEY",
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "BOT_TOKEN",
    "TELEGRAM_TOKEN",
    "AWS_SECRET_ACCESS_KEY",
    "GH_TOKEN",
    "GITHUB_TOKEN"
  ]
}
```

4. If `.claude/status.md` does not exist, create it with this content:

```markdown
# Session log — <basename of project dir>

> Append-only log written by **recall**. Newest entries at the top.

```

5. Print a one-paragraph summary listing exactly which files were created or skipped, and remind the user that:
   - The next session in this project will get a one-line banner from `recall`.
   - `/recall:resume` loads the most recent entries on demand.
   - `CLAUDE_NO_RESUME=1 claude` skips injection for a single fresh session.
   - Deleting `.claude/recall.json` opts the project out completely.

Keep your output terse and structured. No filler, no celebration.
