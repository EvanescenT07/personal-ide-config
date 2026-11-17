# Architecture Overview

This repository combines a portable configuration kit (`ide/`, `agent/`, `scripts/`, `docs/`, `.editorconfig`, `AGENTS.md`) with a Next.js App Router workbench (`src/`) backed by a server-only GitHub API pipeline.

---

## 1. Design Philosophy

1. **Single Canonical Source of Truth:** Engineering rules live once in [`AGENTS.md`](../AGENTS.md). Provider files such as [`agent/antigravity/GEMINI.md`](../agent/antigravity/GEMINI.md) and [`agent/opencode/rules.md`](../agent/opencode/rules.md) act as lightweight adapters or summaries rather than duplicating hundreds of lines that drift over time.
2. **Sanitized Templates vs. Live Host State:** Tracked files never contain personal tokens, API keys, hostnames, or machine-specific filesystem paths. Portable placeholders (`${env:...}`, `{env:...}`, `${HOME}`) are resolved only at deployment time into external local host locations.
3. **Zero-Maintenance Web Discovery:** The Next.js workbench reads the Git tree recursively via the GitHub API and classifies files dynamically by path and filename heuristics (`src/lib/server/classifier.ts`), so adding new configs, skills, or docs requires no UI code changes.
4. **Safe, Reversible Automation:** Installation and deployment scripts default to clear target boundaries, support dry-run previews (`-DryRun` / `--dry-run`), and write timestamped backups (`*.bak.<YYYYMMDD-HHmmss>`) before replacing existing user files.

---

## 2. Separation of Concerns

| Path | Responsibility | Consumed By |
| :--- | :--- | :--- |
| [`.editorconfig`](../.editorconfig) | Cross-editor encoding, line endings, and per-language indentation rules | VS Code-family editors, JetBrains, Neovim, Zed |
| [`AGENTS.md`](../AGENTS.md) | Canonical global AI engineering standards (Sections 1-9) and bootstrap workflow (Section 10) | Antigravity (`~/.gemini/GEMINI.md`), Claude Code, OpenCode, CommandCode, Cursor, Codex |
| [`ide/`](../ide/README.md) | Global `settings.json`, curated 27-extension manifests (`extensions.txt`, `extensions.json`), and non-VS Code stubs (`jetbrains`, `neovim`, `zed`) | `scripts/install-extensions.*`, `scripts/deploy-configs.*`, Web Hub `IDE Configs` |
| [`agent/`](../agent/README.md) | Agent provider templates (`antigravity`, `opencode`, `commandcode`), shared MCP definitions (`mcp`), lockfile/manifest/adapter skill (`skills`), and `.agents/` project template (`workspace`) | `scripts/deploy-configs.*`, AI agents, Web Hub `AI Agents & Rules` |
| [`scripts/`](../scripts/README.md) | Windows PowerShell (`.ps1`) and POSIX Bash (`.sh`) automation for installing extensions and deploying configs | Developers and AI agents executing workstation setup |
| [`docs/`](README.md) | Operational documentation, migration walkthroughs, security audits, and web hub guides | Developers and maintainers |
| [`src/`](../src/app/page.tsx) | Next.js 16 App Router workbench UI and Node.js server pipeline (`ide-config-hub`) | Browser users and optional GitHub push webhooks |

### Deliberately Excluded Artifacts

Runtime state and machine-bound files are excluded from version control and must never be committed:

- `antigravity_state.pbtxt` (onboarding flags and `installation_uuid`)
- Live `~/.gemini/config/config.json` (contains `remoteControlHostname`, plugin `installedFrom` paths, and project grants)
- `~/.gemini/config/projects/*.json` (machine-local repository URIs and worktree states)
- `.env` and `.env.local` (ignored via `.gitignore`)

---

## 3. Next.js Web Hub Data Flow

All GitHub communication and file parsing run strictly inside the Node.js server runtime (`export const runtime = "nodejs"` and `import "server-only"`), keeping `GITHUB_TOKEN` and `GITHUB_WEBHOOK_SECRET` isolated from client bundles.

```text
Browser (Workbench UI)
  ├── ActivityBar / Explorer / FileViewer / JsonKeyExplorer
  ├── RulesHub (Markdown Prompt Composer + Agent/MCP Config Grid)
  ├── HistoryView / FileHistoryDrawer / CommitDetailModal / DiffViewer
  └── CommandPalette (Ctrl/Cmd + K)
         │
         ▼  (RSC initial props + /api/repo/* fetch)
Next.js Node.js Server Pipeline (src/lib/server/)
  ├── github-client.ts   -> Octokit REST v3 + Raw CDN fetch + Next.js ISR tags
  ├── classifier.ts      -> Ignore filter + priority category & language mapping
  ├── jsonc-pipeline.ts  -> jsonc-parser AST keys, comment stripping, token estimates, CLI builder
  ├── diff-pipeline.ts   -> parse-diff unified patch -> line-numbered hunks
  ├── highlight.ts       -> Shiki ("dark-plus") server HTML rendering + bounded Map cache
  └── repo-service.ts    -> Path/ref validation, tree membership checks, search index builder
         │
         ▼  (Server-side GITHUB_TOKEN: 5,000 req/hr authenticated, 60 req/hr fallback)
Upstream GitHub
  ├── REST API v3 (repos/{owner}/{repo}, git/trees, commits, commits/{sha})
  └── raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}
```

### Request Lifecycle Highlights

1. **Initial Page Load (`src/app/page.tsx`, `src/app/history/page.tsx`):** Server Components use `export const dynamic = "force-dynamic"` and call `loadInitialTree()` / `loadInitialHistory()` (`src/lib/server/page-data.ts`) so the first paint receives the classified repository tree (and commit list on `/history`) without exposing tokens.
2. **Tree Classification (`src/lib/server/classifier.ts`):** Evaluates `docs` rules (`PRD*`, `README`, `docs/`) before `scripts/`, `ide/`, and `agent/` checks so documentation inside config directories always appears under `Documentation` rather than `AI Agents & Rules` or `IDE Configs`.
3. **File Inspection (`GET /api/repo/file`):** Validates `path` against the known Git tree (or commit file list when `ref` is a SHA), preventing path traversal or arbitrary CDN requests, then returns Shiki HTML plus parsed JSON entries or Markdown headings.
4. **On-Demand Cache Invalidation (`POST /api/webhooks/github`):** Verifies GitHub's `X-Hub-Signature-256` HMAC using `crypto.timingSafeEqual` and expires `repo-tree`, `repo-commits`, and `repo-file` cache tags immediately on push.
