# AI Agents & MCP Guide

Canonical cross-agent engineering rules, provider configurations (`Antigravity`, `OpenCode`, `CommandCode`), MCP servers, skills registries, and project `.agents/` templates.

---

## 1. Canonical Global Rules (`AGENTS.md`)

[`AGENTS.md`](../AGENTS.md) at the repository root is the single canonical instruction baseline across AI coding assistants:

| Section | Policy |
| :--- | :--- |
| **1. Code Modification & Presentation** | Read-only actions are auto-approved; repository writes, state-altering Git operations, and mutating package commands require explicit user confirmation. Proposals must include rationale and full file paths. |
| **2. Senior Pair Programming** | Critically evaluate assumptions, library choices, and edge cases; propose cleaner alternatives before writing code. |
| **3. Legacy Code Optimization** | Preserve backward compatibility; refactor strictly in order: (1) readable, (2) maintainable, (3) flexible. |
| **4. Design Principles & Quality** | Enforce SOLID, KISS, YAGNI, DRY; eliminate STUPID anti-patterns; use descriptive English identifiers and language style guides (`dart format`, PEP 8, Prettier/ESLint). |
| **5. Error & Exception Handling** | Catch narrow exception types only; route errors through structured loggers with stack traces; never swallow errors or return silent fallbacks. |
| **6. Language & Localization** | Source code, comments, docstrings, and logs exclusively in English; UI strings decoupled into localization files. |
| **7. Context7 MCP Integration** | Proactively query Context7 (`resolve-library-id`, `query-docs`) before writing third-party library or framework code. |
| **8. Anti-Slop Quality Gate** | Apply `antislop` rules: zero filler comments, zero placeholder slop, no generic UI boilerplate, and no em-dashes in prose. |
| **9. Caveman Communication Style** | Terse technical replies by default (`lite`, `full`, `ultra`, `wenyan-*`); automatically switches to full prose for security warnings, irreversible confirmations, or complex sequences. |
| **10. Agent Bootstrap & Adaptation** | Directs any AI agent given this repository to read [`agent/skills/ide-config-adapter/SKILL.md`](../agent/skills/ide-config-adapter/SKILL.md), inspect the workstation read-only, and safely merge configs. |

---

## 2. Antigravity (`agent/antigravity/`)

Templates target `~/.gemini/` (`%USERPROFILE%\.gemini\` on Windows):

| Repo Source | Host Target | Notes |
| :--- | :--- | :--- |
| [`AGENTS.md`](../AGENTS.md) | `~/.gemini/GEMINI.md` | Deployed directly from root `AGENTS.md` so rules stay synchronized |
| [`agent/antigravity/GEMINI.md`](../agent/antigravity/GEMINI.md) | Reference only | Lightweight pointer inside the repo preventing rule duplication |
| [`agent/antigravity/skills.json`](../agent/antigravity/skills.json) | `~/.gemini/config/skills.json` | Points to `{"entries":[{"path":"${HOME}/.agents/skills"}]}` (`-ResolvePaths` expands `${HOME}`) |
| [`agent/antigravity/config.template.json`](../agent/antigravity/config.template.json) | `~/.gemini/config/config.template.json` | Lists 5 enabled plugins (`android-cli-plugin`, `antislop`, `coderabbit`, `firebase`, `google-antigravity-sdk`) and safe read-only `globalPermissionGrants` (`git status`, `git diff`, `git log`, `Get-ChildItem`, `ls`) |

### Protected Runtime Files

Live `~/.gemini/config/config.json` is never overwritten by `scripts/deploy-configs.*`. Merge `plugins` and `globalPermissionGrants` manually from `config.template.json` so machine-specific `remoteControlHostname`, `installedFrom` metadata, and project entries remain intact. Runtime files (`antigravity_state.pbtxt`, `~/.gemini/config/projects/*.json`, OAuth tokens) stay excluded from git.

---

## 3. OpenCode (`agent/opencode/`)

Templates target `~/.config/opencode/` (or `$XDG_CONFIG_HOME/opencode/`):

- [`agent/opencode/opencode.jsonc`](../agent/opencode/opencode.jsonc): Uses `$schema: "https://opencode.ai/config.json"`, sets `"model": "interpreter/sonnet-4.5"`, loads `"instructions": ["rules.md"]`, and enables two local MCP servers:
  - `github`: `npx -y @modelcontextprotocol/server-github` reading `{env:GITHUB_TOKEN}` into `GITHUB_PERSONAL_ACCESS_TOKEN`.
  - `rea`: `npx -y rea-agents@6.8.0 mcp` (wrap with `["cmd.exe", "/d", "/c", "npx", "-y", "rea-agents@6.8.0", "mcp"]` on Windows if the bare `npx` shim fails).
- [`agent/opencode/rules.md`](../agent/opencode/rules.md): Concise 10-point rules summary kept in parity with `AGENTS.md`.
- [`agent/opencode/package.json`](../agent/opencode/package.json): Pins `"@opencode-ai/plugin": "1.18.5"`. Run `npm install` (or `bun install`) inside `~/.config/opencode/` if local plugin resolution is required.

---

## 4. CommandCode (`agent/commandcode/`)

Templates target `~/.opencode/` (`%USERPROFILE%\.opencode\` on Windows):

- [`agent/commandcode/opencode.jsonc`](../agent/commandcode/opencode.jsonc): Configures `"model": "commandcode/gpt-4o"`, `"skills": { "paths": ["~/.opencode/skills"] }`, OpenAI-compatible provider `commandcode` (`https://api.commandcode.ai/v1`, `env: ["COMMANDCODE_API_KEY"]`), remote `context7` (`https://mcp.context7.com/mcp`), and local `playwright` (`npx @playwright/mcp@latest`). If your client does not expand `~` in `skills.paths`, replace `"~/.opencode/skills"` in the deployed copy with an absolute forward-slash home path.
- [`agent/commandcode/package.json`](../agent/commandcode/package.json): Pins `"@opencode-ai/plugin": "1.18.12"`.

---

## 5. Shared MCP Servers (`agent/mcp/`)

Two sanitized templates are provided under [`agent/mcp/`](../agent/mcp/README.md):

- [`agent/mcp/mcp_config.json`](../agent/mcp/mcp_config.json): Full 7-server bundle deployed to `~/.gemini/config/mcp_config.json` (and copyable to `~/.gemini/antigravity/mcp_config.json`).
- [`agent/mcp/mcp_config_http.json`](../agent/mcp/mcp_config_http.json): Remote HTTP-only subset (`context7` and `stitch`) for environments without local `node` or `uv`.

| Server | Transport | Runtime / Command | Required Env Var |
| :--- | :--- | :--- | :--- |
| `context7` | stdio (or HTTP in `mcp_config_http.json`) | `npx -y @upstash/context7-mcp@latest --api-key ${env:CONTEXT7_API_KEY}` | `CONTEXT7_API_KEY` |
| `stitch` | HTTP (`https://stitch.googleapis.com/mcp`) | HTTPS header `X-Goog-Api-Key` | `STITCH_API_KEY` |
| `graphify` | stdio | `uv run --with graphifyy --with mcp python -m graphify.serve` | None |
| `playwright` | stdio | `npx @playwright/mcp@latest` | None |
| `rea` | stdio | `npx -y rea-agents@6.8.0 mcp` | None |
| `flow-connector` | stdio | `flow-auto-mcp` on `PATH` | None |
| `dart-mcp-server` | stdio | `dart mcp-server` (`$typeName` is Antigravity metadata; remove for other hosts if rejected) | None |

### Cross-Platform Execution Notes

- **Windows GUI MCP Hosts:** If a stdio server fails to spawn via bare `"npx"`, use `"npx.cmd"` (commonly needed for `context7`) or wrap with `"command": "cmd.exe"` and `"args": ["/d", "/c", "npx", ...]` (commonly needed for `rea`).
- **Env Expansion:** Some MCP clients do not expand `${env:...}` inside JSON `args` or `headers`. Running `deploy-configs.* -ResolvePaths` resolves any already-exported env variables into the deployed copy only; otherwise set values directly in your local `~/.gemini/` copy.

---

## 6. Skills & Plugins (`agent/skills/`)

[`agent/skills/manifest.json`](../agent/skills/manifest.json) catalogs every skill and plugin tracked by this kit:

- **Antigravity Marketplace Plugins (5):** `android-cli-plugin`, `antislop`, `coderabbit`, `firebase`, `google-antigravity-sdk` (installed via Antigravity Plugins Manager UI).
- **Lockfile Skills (15):** Recorded in [`agent/skills/.skill-lock.json`](../agent/skills/.skill-lock.json) across `vercel-labs/skills` (`find-skills`), `anthropics/skills` (`pptx`, `pdf`, `webapp-testing`, `xlsx`), `MiniMax-AI/skills` (`android-native-dev`), `firebase/skills` (`firebase-auth-basics`), `flutter/skills` (6 Flutter architecture/routing/layout/HTTP/JSON skills), `auth0/agent-skills` (`auth0`), and `figma/mcp-server-guide` (`figma-design-to-code`).
- **Global Standalone Skills (5):** `caveman`, `flutter-animating-apps`, `graphify` (`uv tool install graphifyy`), `reels-storyboard-architect`, `reverse-engineer-anything` (`npx -y rea-agents@6.8.0`).
- **Repository Skill (1):** [`agent/skills/ide-config-adapter/SKILL.md`](../agent/skills/ide-config-adapter/SKILL.md).

Restore lockfile skills globally on a new machine:

```bash
# Example individual installs (see agent/skills/manifest.json for every entry)
npx skills add vercel-labs/skills --skill find-skills -g -y
npx skills add flutter/skills --skill flutter-apply-architecture-best-practices -g -y
npx skills add anthropics/skills --skill pdf -g -y
```

---

## 7. Project `.agents/` Workspace Template (`agent/workspace/`)

[`agent/workspace/`](../agent/workspace/README.md) provides a portable `.agents/` directory for individual codebases:

- [`skills.json`](../agent/workspace/skills.json): References `${HOME}/.agents/skills`.
- [`rules/graphify.md`](../agent/workspace/rules/graphify.md): Always-on rule (`trigger: always_on`) instructing agents to query `graphify-out/graph.json` (`graphify query`, `path`, `explain`, `update`) before scanning raw files.
- [`workflows/graphify.md`](../agent/workspace/workflows/graphify.md): `/graphify` workflow entry point.

Deploy into any project repository:

```powershell
.\scripts\deploy-configs.ps1 -Target workspace -WorkspacePath D:\Projects\my-app -ResolvePaths
```

```bash
./scripts/deploy-configs.sh --target workspace --workspace ~/projects/my-app --resolve-paths
```

Note: When running `deploy-configs` with `-Target all` / `--target all` inside this config repository itself, the `workspace` target is skipped automatically unless `-Target workspace` or a different `-WorkspacePath` / `--workspace` is specified.
