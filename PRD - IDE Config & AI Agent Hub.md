# Product Requirements Document (PRD): IDE Config & AI Agent Hub

| Metadata | Details |
| :--- | :--- |
| **Project Name** | IDE Config & AI Agent Hub |
| **Package Name** | `ide-config-hub` |
| **Source Repository** | `https://github.com/EvanescenT07/vscode-config` (configurable via `GITHUB_OWNER` / `GITHUB_REPO`) |
| **Document Status** | Active / Implemented |
| **Target Architecture** | Full-Stack Next.js (App Router + Node.js Runtime) & Cross-IDE / AI Agent Config Kit |
| **Primary Goal** | Centralize cross-IDE configurations, AI agent rules/skills/MCP templates, installation scripts, and Git repository history for instant discovery, 1-click copying, and diff inspection. |

---

## 1. Executive Summary & Objectives

### 1.1 Problem Statement
Developers and AI-assisted engineers work across multiple operating systems, VS Code-family editors (`code`, `agy`, `cursor`, `windsurf`, `codium`), non-VS Code editors (JetBrains, Neovim, Zed), and AI coding agents (Antigravity, OpenCode, CommandCode). Navigating GitHub's standard web interface to copy `settings.json`, strip JSONC comments, install extension stacks across editors, assemble modular AI agent instructions, or roll back broken settings from commit history requires excessive manual steps.

### 1.2 Product Vision
Pair a portable, sanitized cross-IDE and AI agent configuration repository (`ide/`, `agent/`, `scripts/`, `docs/`, `.editorconfig`, `AGENTS.md`) with a fast, IDE-themed **Next.js + Node.js web workbench** (`src/`) that dynamically classifies the Git tree and provides 1-click copy ergonomics, JSON key exploration, prompt composition, and commit/diff time-travel.

### 1.3 Key Objectives
1. **Zero-Maintenance Sync**: Dynamically classify the upstream Git tree (`src/lib/server/classifier.ts`) so newly pushed IDE configs, agent rules, skills, or scripts appear in the workbench without hardcoding file paths.
2. **Cross-IDE & Agent Ergonomics**: Support 1-click raw/strict-JSON copy, flattened JSON key copy, multi-IDE extension CLI switching (`code`, `agy`, `cursor`, `windsurf`, `codium`), and prompt concatenation exclusively across Markdown/text AI rules.
3. **Resilient Server Pipeline**: Keep `GITHUB_TOKEN` and `GITHUB_WEBHOOK_SECRET` strictly server-side (`import "server-only"`), parse JSONC/diffs/Shiki highlighting on the Node.js runtime, and invalidate Next.js ISR caches on demand via GitHub webhooks.

---

## 2. System & Repository Architecture

### 2.1 Repository Layout

```text
.
├── .editorconfig                 # Universal cross-IDE formatting baseline
├── AGENTS.md                     # Canonical AI agent engineering guidelines & bootstrap rules
├── README.md                     # Top-level guide & quick start
├── PRD - IDE Config & AI Agent Hub.md
├── package.json                  # Next.js web workbench manifest ("ide-config-hub")
├── .env.example                  # Repository & GitHub API env template
├── ide/
│   ├── README.md                 # Cross-IDE parity guide & user-settings paths
│   ├── settings.json             # Sanitized VS Code-family JSONC settings
│   ├── extensions.txt            # Grouped 27-extension install list
│   ├── extensions.json           # Workspace .vscode/extensions.json template
│   └── stubs/
│       ├── jetbrains/            # .ideavimrc & JetBrains parity notes
│       ├── neovim/               # init.lua starter stub & LSP/formatter mapping
│       └── zed/                  # Zed settings.json & migration notes
├── agent/
│   ├── README.md                 # AI agent templates overview
│   ├── antigravity/              # GEMINI.md, config.template.json, skills.json
│   ├── commandcode/              # opencode.jsonc, package.json
│   ├── mcp/                      # mcp_config.json, mcp_config_http.json
│   ├── opencode/                 # opencode.jsonc, rules.md, package.json
│   ├── skills/                   # .skill-lock.json, manifest.json, ide-config-adapter/SKILL.md
│   └── workspace/                # Project .agents/ template (skills, rules, workflows)
├── scripts/
│   ├── README.md                 # Automation usage & OS target path matrix
│   ├── install-extensions.ps1    # Windows PowerShell multi-IDE extension installer
│   ├── install-extensions.sh     # macOS/Linux Bash multi-IDE extension installer
│   ├── deploy-configs.ps1        # Windows config deployment with backups & dry-run
│   └── deploy-configs.sh         # macOS/Linux config deployment with backups & dry-run
├── docs/                         # Long-form guides (architecture, ide-migration, ai-agents, security, web-hub)
└── src/                          # Next.js App Router + Node.js data pipeline web hub
```

### 2.2 Web Hub Runtime Flow

```text
+-----------------------------------------------------------------------+
|                       CLIENT (Next.js React UI)                       |
|  +-----------------+  +--------------------+  +--------------------+  |
|  |   File Viewer   |  |  AI Agents & Rules |  | Commit & Diff View |  |
|  |  Key Explorer   |  |   Prompt Composer  |  |  Timeline & Modal  |  |
|  +-----------------+  +--------------------+  +--------------------+  |
|           |                     |                       |             |
|           +---------------------+-----------------------+             |
|                                 | (JSON API / Server Component Props) |
+---------------------------------|-------------------------------------+
                                  v
+-----------------------------------------------------------------------+
|                   BACKEND (Next.js Node.js Runtime)                   |
|  1. Auto-Discovery & Priority Classifier (src/lib/server/classifier)  |
|  2. JSONC AST Parser & Extension CLI Builder (jsonc-pipeline)         |
|  3. Server-Side Shiki Highlighter with LRU Cache (highlight.ts)       |
|  4. Unified Git Patch Parser (diff-pipeline.ts via parse-diff)        |
|  5. ISR Cache Tags (repo-meta, repo-tree, repo-file, repo-commits)    |
+---------------------------------|-------------------------------------+
                                  v (Server-side GITHUB_TOKEN)
+-----------------------------------------------------------------------+
|              EXTERNAL SOURCE: GitHub REST API v3 & Raw CDN            |
|        Configured via GITHUB_OWNER / GITHUB_REPO (default: vscode-config)
+-----------------------------------------------------------------------+
```

### 2.3 Technology Stack
* **Framework**: Next.js 16 (App Router, React 19, Server Components + Route Handlers)
* **Backend Runtime**: Node.js (`export const runtime = "nodejs"`)
* **Language & Styling**: TypeScript 5.9, Tailwind CSS, `lucide-react`
* **Server Libraries**:
  * `@octokit/rest` and `@octokit/request-error`: GitHub REST API client with rate-limit tracking
  * `jsonc-parser`: Fault-tolerant JSONC AST parser for comments and trailing commas
  * `parse-diff`: Unified patch parser producing structured old/new line numbers
  * `shiki`: Server-side syntax highlighting (`dark-plus` theme across `jsonc`, `markdown`, `typescript`, `javascript`, `yaml`, `toml`, `lua`, `viml`, `shellscript`, `powershell`, `bat`, `ini`, `text`)

---

## 3. Dynamic Auto-Detection & Categorization Pipeline

`src/lib/server/classifier.ts` filters out web-app internals (`src/`, `node_modules/`, `.next/`, `.git/`, `package.json`, lockfiles, `.env*`, binary assets) and evaluates non-ignored blobs in strict priority order:

| Priority | Category | Matching Heuristics | Purpose in UI |
| :--- | :--- | :--- | :--- |
| 1 | `docs` (`Documentation`) | `^PRD[\s._-]`, `DOC_FILENAME` (`README*`, `LICENSE*`, `CHANGELOG*`, `CONTRIBUTING*`, `CODE_OF_CONDUCT*`), `^docs/` | Evaluated first so `ide/README.md`, `agent/**/README.md`, `scripts/README.md`, and `docs/*.md` never pollute `aiRules` or `ideConfigs`. |
| 2 | `scripts` (`Scripts & Automation`) | `*.sh`, `*.ps1`, `*.bat`, `*.cmd`, `*.zsh`, `Makefile`, `Dockerfile`, `^scripts/` | Groups PowerShell and Bash setup/deployment scripts together. |
| 3 | `ideConfigs` (`IDE Configs`) | `^ide/`, `.editorconfig`, `.ideavimrc`, `.vimrc`, `.prettierrc*`, `.eslintrc*`, `settings.json`, `keybindings.json`, `extensions.json`, `extensions.txt`, `tasks.json`, `launch.json` | Captures primary IDE settings, extension lists, `.editorconfig`, and `ide/stubs/` (`jetbrains`, `neovim`, `zed`). |
| 4 | `aiRules` (`AI Agents & Rules`) | `^agent/`, `AI_DIRECTORY` (`rules`, `prompts`, `agents`, `agent`, `skills`, `cursor`, `copilot`, `claude`, `windsurf`, `opencode`, `commandcode`, `antigravity`), or `AI_FILENAME` (`AGENTS.md`, `SKILL.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, `rules.md`, `opencode.jsonc`, `mcp_config*.json`, `.skill-lock.json`, `*rules*`, `*prompt*`) | Groups all agent instructions, skills, and structured agent/MCP JSON configs under one section. `isAiRulePath()` sets `isAiRule = true` strictly for Markdown/text instructions (`!isJson`) so prompt concatenation excludes JSON files. |
| 5 | `ideConfigs` (fallback) | `IDE_DIRECTORY` (`.vscode`, `vscode`, `ide`, `config`, `settings`, `snippets`, `profiles`), `IDE_EXTENSION` (`json`, `jsonc`, `yaml`, `yml`, `toml`, `lua`, `vim`, `ideavimrc`, `editorconfig`, `code-snippets`, `code-profile`), or `*extensions*.txt` | Supports custom or legacy IDE directory layouts automatically. |
| 6 | `docs` (fallback) | `*.md`, `*.mdx`, `*.txt`, `*.pbtxt`, or unclassified text files | Safe fallback for miscellaneous documentation. |

### 3.1 Language Mapping for Dotfiles & Stubs
`languageFor(path)` inspects both trailing extensions and leading-dot filenames so `.editorconfig` maps to `ini`, `.ideavimrc` and `.vimrc` map to `viml`, `init.lua` maps to `lua`, `.cursorrules` maps to `markdown`, and `*.ps1` / `*.sh` map to `powershell` / `shellscript`.

---

## 4. Core Functional Requirements

### 4.1 Feature 1: IDE Config Viewer & Granular Copy Engine (`FileViewer.tsx`, `JsonKeyExplorer.tsx`)
* **FR-1.1 Context-Aware Copy**: Primary sticky action adapts label to file role (`Copy Extension List`, `Copy Rule`, `Copy Config`, `Copy Script`, `Copy File`).
* **FR-1.2 JSONC Strip-Comments Dropdown**: For `.json` and `.jsonc` files, users can copy either **Raw JSONC (with comments)** or **Strict JSON (comments stripped via `jsonc-parser`)**.
* **FR-1.3 Interactive JSON Key Explorer**: Parses JSON/JSONC ASTs into flattened dotted keys (`extractJsonEntries`) with type badges (`string`, `number`, `boolean`, `null`, `array`, `object`), keyword search, and per-key copy.
* **FR-1.4 Multi-IDE Extension Quick Install**: `buildExtensionInstallCommand` supports both `ide/extensions.txt` (stripping full-line `#` and inline `#` comments) and `ide/extensions.json`, ignoring non-extension scripts/docs. `FileViewer` renders an IDE CLI switcher (`code`, `agy`, `cursor`, `windsurf`, `codium`) so users can copy the exact `--install-extension` command for their editor.

### 4.2 Feature 2: AI Agents & Rules Hub (`RulesHub.tsx`)
* **FR-2.1 Prompt vs. Config Separation**: `RulesHub` splits `category === "aiRules"` files by `file.isAiRule`:
  * **Prompt & Skill Instructions (`isAiRule: true`)**: Selectable Markdown/text cards (`AGENTS.md`, `GEMINI.md`, `rules.md`, `SKILL.md`, `graphify.md`) with token estimates, extracted headings, and multi-select checkboxes.
  * **Agent & MCP Configurations (`isAiRule: false`)**: Structured JSON/JSONC cards (`mcp_config.json`, `opencode.jsonc`, `config.template.json`, `.skill-lock.json`, `manifest.json`, `skills.json`) rendered cleanly without prompt-combiner checkboxes.
* **FR-2.2 Dual Markdown Modes**: Toggle between **Rendered** Markdown and **Raw Prompt** / **Raw Markdown**.
* **FR-2.3 Multi-Rule Prompt Builder**: Floating action bar tracks selected Markdown rules and estimated token budget, copying concatenated rules delimited by `\n\n---\n<!-- Source: {filepath} -->\n\n`.

### 4.3 Feature 3: Repository Change History & Diff Inspector (`HistoryView.tsx`, `FileHistoryDrawer.tsx`, `CommitDetailModal.tsx`, `DiffViewer.tsx`)
* **FR-3.1 Global & File-Scoped Timelines**: Dedicated `/history` route and slide-over per-file history drawer (`?path={filepath}`).
* **FR-3.2 Structured Unified & Split Diffs**: Parses commit patches with `parse-diff` into line-numbered hunks with collapsible per-file sections.
* **FR-3.3 Historical Blob Time-Travel**: Every modified file in `DiffViewer` includes a `Copy file at this commit` button fetching `raw.githubusercontent.com/{owner}/{repo}/{sha}/{filepath}`.

### 4.4 Feature 4: Global Command Palette (`CommandPalette.tsx`)
* **FR-4.1 Fuzzy Navigation (`Ctrl/Cmd + K`)**: On-demand `/api/repo/index` search across workbench Actions, classified Files (`rule`, `agent`, or format badges), flattened JSON keys (1-click copy), and Markdown headings.

---

## 5. Backend API Specification (`src/app/api/`)

| Endpoint | Purpose | Upstream GitHub Call | Caching Strategy |
| :--- | :--- | :--- | :--- |
| `GET /api/repo/tree` | Fetches default branch metadata, recursive tree, latest commit summary, and rate-limit status. | `GET /repos/{owner}/{repo}/git/trees/{branch}?recursive=1` | `revalidate: 300`, tags `["repo-tree"]` |
| `GET /api/repo/file?path=...&ref=...&raw=1` | Validates path membership, returns raw text or Shiki-highlighted HTML + JSONC/Markdown/CLI metadata. | `raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}` | Immutable cache (`max-age=31536000`) when `ref` is a commit SHA; `revalidate: 300` otherwise |
| `GET /api/repo/index` | Builds bounded search index (up to 80 JSON/Markdown/rule files <= 250 KB) with concurrency limit 6. | `raw.githubusercontent.com` (parallel batch) | Inherits `repo-file` / `repo-tree` tags |
| `GET /api/repo/commits?path=...&page=...&per_page=...` | Paginated commit history globally or for one file path. | `GET /repos/{owner}/{repo}/commits` | `revalidate: 120`, tags `["repo-commits", "repo-tree"]` |
| `GET /api/repo/commits/[sha]` | Returns commit metadata, stats, and parsed unified diff hunks. | `GET /repos/{owner}/{repo}/commits/{sha}` | `revalidate: false` (immutable SHA) |
| `POST /api/webhooks/github` | Verifies `X-Hub-Signature-256` with `crypto.timingSafeEqual` and purges `repo-tree`, `repo-commits`, `repo-file`. | None (inbound webhook) | Immediate tag invalidation |

---

## 6. Security & Environment Configuration

### 6.1 Security Invariants
* **Server-Only Credentials**: `GITHUB_TOKEN` and `GITHUB_WEBHOOK_SECRET` are never prefixed with `NEXT_PUBLIC_` and are accessed solely inside `"server-only"` modules or Route Handlers.
* **Path Traversal & SSRF Prevention**: `normalizeRepoPath`, `normalizeRef`, and `assertPathAccessible` validate every requested path against the known Git tree or commit file list before fetching raw CDN blobs.
* **Webhook Verification**: `POST /api/webhooks/github` returns `503` if `GITHUB_WEBHOOK_SECRET` is unset and validates HMAC SHA-256 signatures in constant time.

### 6.2 `.env.example` Configuration

```ini
# Target GitHub repository (update GITHUB_REPO if the repository is renamed on GitHub)
GITHUB_OWNER="EvanescenT07"
GITHUB_REPO="vscode-config"
GITHUB_DEFAULT_BRANCH="main"

# Optional fine-grained, read-only GitHub PAT (raises API limit from 60 to 5,000 req/hr).
# Server-only: never prefix with NEXT_PUBLIC_ or expose to the browser.
GITHUB_TOKEN=""

# Optional HMAC secret used to verify GitHub push webhooks at POST /api/webhooks/github.
GITHUB_WEBHOOK_SECRET=""
```

### 6.3 `src/` Directory Structure

```text
src/
├── app/
│   ├── api/
│   │   ├── repo/
│   │   │   ├── commits/route.ts
│   │   │   ├── commits/[sha]/route.ts
│   │   │   ├── file/route.ts
│   │   │   ├── index/route.ts
│   │   │   └── tree/route.ts
│   │   └── webhooks/github/route.ts
│   ├── history/page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── components/
│   ├── ai-rules/RulesHub.tsx
│   ├── command-palette/CommandPalette.tsx
│   ├── config-viewer/{CodeViewer,FileViewer,JsonKeyExplorer,MarkdownView}.tsx
│   ├── history-diff/{CommitDetailModal,CommitTimeline,DiffViewer,FileHistoryDrawer,HistoryView}.tsx
│   ├── ui/{CopyButton,GitHubMark,ToastProvider}.tsx
│   └── workbench/{ActivityBar,Explorer,FileTypeIcon,StatusBar,Workbench,view-types}.tsx
└── lib/
    ├── client/api.ts
    ├── server/{classifier,diff-pipeline,github-client,highlight,jsonc-pipeline,page-data,repo-service,route-utils}.ts
    ├── utils/{clipboard,cn,format}.ts
    └── types.ts
```
