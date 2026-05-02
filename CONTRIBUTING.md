# Contributing to recall

Thanks for considering a contribution. recall is intentionally tiny — keeping it that way is a feature.

## Local development

```bash
git clone https://github.com/tonimaxx/recall.git
cd recall
brew install jq shellcheck   # or apt-get / your package manager

# run the smoke test
bash tests/smoke.sh

# load into a project for live testing
claude --plugin-dir /path/to/recall
```

In a Claude Code session loaded with `--plugin-dir`, run `/reload-plugins` to pick up changes without restarting.

## What we accept

- **Bug fixes** — always welcome.
- **Smaller, more targeted redaction patterns** — yes please.
- **Compatibility shims** for new Claude Code hook payload fields — yes.
- **Documentation polish** — yes.

## What we decline

- New hook events that aren't justified by a concrete user-facing benefit.
- LLM-summarization of entries (deliberately out of scope — see [README](./README.md#design-principles)).
- Telemetry, phone-home, "anonymous usage stats." Hard no.
- Switching from shell + jq to Node/Python/Rust runtime. The dependency budget is intentional.

## Style

- Shell: `set -euo pipefail` always, shellcheck-clean (CI enforces).
- Markdown: short lines, clear headings, no decorative emoji-spam.
- Commit messages: imperative present, ≤72-char subject, body for the *why* if non-obvious.

## Reporting bugs

Please include:
- Claude Code version (`claude --version`)
- macOS/Linux + shell version
- Contents of `.claude/recall.json` (redact what you must)
- Last few lines of `.claude/status.md` if relevant
- `RECALL_DEBUG=1` output if reproducible

Open an issue with that and we can move fast.
