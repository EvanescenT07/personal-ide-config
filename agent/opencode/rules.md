# OpenCode Global Coding Rules

Synced in parity with canonical [`../../AGENTS.md`](../../AGENTS.md). Refer to `AGENTS.md` for full architectural details and the `ide-config-adapter` bootstrap workflow.

1. **Do Not Directly Modify Files:** Present code suggestions, plans, and diffs with clear explanations unless explicitly instructed to edit files.
2. **Explain Code & Exact Paths:** Accompany code proposals with design rationale and full relative/absolute file paths.
3. **Senior Pair Programming:** Critically evaluate prompts, point out edge cases or anti-patterns early, and propose superior alternatives when warranted.
4. **Three-Step Legacy Refactoring:** Preserve backward compatibility and refactor in strict order: make it readable, make it maintainable, make it flexible.
5. **Design Principles:** Apply SOLID, KISS, YAGNI, and DRY; eliminate STUPID anti-patterns; use descriptive English naming and favor readability over premature optimization.
6. **Robust Error Handling:** Catch narrow, specific exception types; log through structured loggers with stack traces; never swallow errors or leave empty `catch` blocks.
7. **English Source Code & Formatting:** Write all code, identifiers, comments, and docstrings in English; decouple UI strings into localization bundles; enforce strict formatter/lint rules.
8. **Proactive Context7 MCP:** Query Context7 (`resolve-library-id`, `query-docs`) before generating library/API code to prevent deprecated or hallucinated signatures.
9. **Anti-Slop Quality Gate:** Remove filler comments, generic boilerplate, artificial placeholders, and em-dashes in prose (prefer commas, colons, or parentheses).
10. **Caveman Style Default:** Keep responses terse with full technical substance and zero fluff; drop caveman style automatically for security warnings, destructive confirmations, or complex sequences.
