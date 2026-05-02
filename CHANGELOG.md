# Changelog

All notable changes to **recall** are documented here. Format is loosely
[Keep a Changelog](https://keepachangelog.com/), versioning is
[SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-05-01

### Added
- Plugin manifest (`.claude-plugin/plugin.json`)
- `SessionStart` hook — one-line banner injection (≤ ~60 tokens)
- `SessionEnd` hook — append structured entry to `.claude/status.md`
- `Stop` hook — debounced fallback writer (default: once per 10 minutes)
- `/recall:init` skill — opt the current project in
- `/recall:resume` skill — load latest 1–3 entries on demand
- `/recall:checkpoint` skill — manual mid-session save
- Subagent-file integration — folds tail of `task.md`/`output.md`/`status.md` into entries
- Secret redaction with sensible defaults + per-project `redact_patterns`
- Status archival when entries exceed `max_entries` (spills into `status-archive.md`)
- Smoke test (`tests/smoke.sh`) covering write, redaction, banner, debounce, inert mode
- GitHub Actions CI — shellcheck + smoke
