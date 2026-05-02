---
description: Load the latest recall entries from .claude/status.md so the model can resume work with prior context. Does nothing if the project hasn't enabled recall.
disable-model-invocation: true
---

# recall · resume

You are loading prior session context for the user. Do exactly:

1. Verify `.claude/recall.json` exists in the project root. If absent, print: "recall is not enabled in this project. Run `/recall:init` first." Stop.
2. Read `.claude/status.md`.
3. Extract the **most recent 1–3 entries** (each starts with `## `). Skip the file header.
4. Quote them verbatim back to the user, prefixed with a single line:

   > **recall · resuming context from `.claude/status.md`**

5. Then add a one-line summary of what's loaded and ask: "Continue from here, or take a different direction?"

Constraints:
- Do not paraphrase or compress entries — quote them.
- If `$ARGUMENTS` is a number `N`, load `N` entries instead of 3 (cap at 10).
- If status.md is empty (no `## ` entries), say so and offer `/recall:checkpoint` to save the first one.
- This skill is read-only. Never modify files.
