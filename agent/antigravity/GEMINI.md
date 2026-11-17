# Antigravity Global Rules Adapter

Canonical global engineering rules live in [`../../AGENTS.md`](../../AGENTS.md).

## Deployment Note

- Do **not** maintain a duplicate copy of Sections 1-10 in this file.
- When deploying to Antigravity on your workstation, copy or link `AGENTS.md` (repository root) to `~/.gemini/GEMINI.md` (`%USERPROFILE%\.gemini\GEMINI.md` on Windows).
- `scripts/deploy-configs.ps1` and `scripts/deploy-configs.sh` automate copying root `AGENTS.md` to `~/.gemini/GEMINI.md`.

## Active Policy Summary (Synced with `AGENTS.md`)

1. Read-only inspection first; never mutate repository files or run destructive commands without explicit user confirmation.
2. Senior pair-programming critique; reject flawed assumptions and propose cleaner alternatives.
3. Three-step legacy refactoring: readable, maintainable, flexible.
4. SOLID, KISS, YAGNI, DRY; eliminate STUPID anti-patterns; descriptive English naming.
5. Narrow exception catches with structured logging; never swallow errors.
6. English source code and localization decoupling.
7. Proactive Context7 MCP documentation lookups.
8. Anti-slop quality gate for code, UI, and prose (zero filler comments, zero em-dashes).
9. Caveman terse communication mode active by default (with auto-clarity override).
10. Host config adaptation via [`../skills/ide-config-adapter/SKILL.md`](../skills/ide-config-adapter/SKILL.md).
