# Web Hub Guide (`ide-config-hub`)

Setup, environment configuration, dynamic Git tree classification, workbench features, API endpoints, and deployment guide for the Next.js workbench under `src/`.

---

## 1. Local Setup & Scripts

### Prerequisites

- **Node.js:** 20+ LTS (`npm` included)
- **Target GitHub Repository:** Accessible via GitHub REST API v3 and Raw CDN (defaults to `EvanescenT07/vscode-config`)

### Installation

```bash
npm install
cp .env.example .env.local   # PowerShell: Copy-Item .env.example .env.local
```

Edit `.env.local`:

```ini
GITHUB_OWNER="EvanescenT07"
GITHUB_REPO="vscode-config"
GITHUB_DEFAULT_BRANCH="main"

# Optional read-only Fine-Grained PAT (60 -> 5,000 req/hr). Never prefix with NEXT_PUBLIC_.
GITHUB_TOKEN=""

# Optional HMAC secret for POST /api/webhooks/github
GITHUB_WEBHOOK_SECRET=""
```

### NPM Scripts (`package.json`)

| Command | Action |
| :--- | :--- |
| `npm run dev` | Start Next.js development server |
| `npm run build` | Build production Next.js bundle |
| `npm run start` | Serve production build |
| `npm run typecheck` | Run `tsc --noEmit` |

---

## 2. Dynamic Tree Classifier Rules (`src/lib/server/classifier.ts`)

`classifyBlob()` filters out web-app internals (`node_modules/`, `.next/`, `.git/`, `.vercel/`, `src/`, `public/`, `out/`, `coverage/`, `package.json`, lockfiles, `tsconfig*`, `next.config.*`, `tailwind.config.ts`, `postcss.config.*`, `.gitignore`, `.DS_Store`, `Thumbs.db`, `.env*`, and binary extensions) before classifying every remaining Git blob in strict priority order:

| Priority | Category | Matching Rules | Examples |
| :--- | :--- | :--- | :--- |
| 1 | `docs` (`Documentation`) | `^PRD[\s._-]`, `DOC_FILENAME` (`README*`, `LICENSE*`, `CHANGELOG*`, `CONTRIBUTING*`, `CODE_OF_CONDUCT*`), or `^docs/` | `README.md`, `ide/README.md`, `agent/README.md`, `scripts/README.md`, `docs/*.md`, `PRD - IDE Config & AI Agent Hub.md` |
| 2 | `scripts` (`Scripts & Automation`) | `*.sh`, `*.ps1`, `*.bat`, `*.cmd`, `*.zsh`, `Makefile`, `Dockerfile`, or `^scripts/` | `scripts/install-extensions.ps1`, `scripts/deploy-configs.sh` |
| 3 | `ideConfigs` (`IDE Configs`) | `^ide/` or `IDE_FILENAME` (`.editorconfig`, `.ideavimrc`, `.vimrc`, `.prettierrc*`, `.eslintrc*`, `settings.json`, `keybindings.json`, `extensions.json`, `extensions.txt`, `tasks.json`, `launch.json`) | `.editorconfig`, `ide/settings.json`, `ide/extensions.txt`, `ide/stubs/neovim/init.lua` |
| 4 | `aiRules` (`AI Agents & Rules`) | `^agent/`, `AI_DIRECTORY` (`rules`, `prompts`, `agents`, `agent`, `skills`, `cursor`, `copilot`, `claude`, `windsurf`, `opencode`, `commandcode`, `antigravity`), or `AI_FILENAME` (`AGENTS.md`, `SKILL.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, `rules.md`, `opencode.jsonc`, `mcp_config*.json`, `.skill-lock.json`, `*rules*`, `*prompt*`) | `AGENTS.md`, `agent/mcp/mcp_config.json`, `agent/skills/ide-config-adapter/SKILL.md`, `agent/workspace/rules/graphify.md` |
| 5 | `ideConfigs` (fallback) | `IDE_DIRECTORY` (`.vscode`, `vscode`, `ide`, `config`, `settings`, `snippets`, `profiles`), `IDE_EXTENSION` (`json`, `jsonc`, `yaml`, `yml`, `toml`, `lua`, `vim`, `ideavimrc`, `editorconfig`, `code-snippets`, `code-profile`), or `*extensions*.txt` | Legacy or custom IDE directories |
| 6 | `docs` (fallback) | `*.md`, `*.mdx`, `*.txt`, `*.pbtxt`, or unclassified files | Miscellaneous text files |

### Prompt-Combinable Flag (`isAiRulePath`) & Shiki Languages

- `isAiRulePath(path)` returns `true` only when `category === "aiRules"` and the file is `.md`, `.mdx`, `.mdc`, `.txt`, or `.cursorrules`. Structured JSON/JSONC agent configs (`mcp_config.json`, `opencode.jsonc`, `config.template.json`, `.skill-lock.json`, `manifest.json`, `skills.json`) have `isAiRule: false` so the multi-rule prompt combiner never mixes JSON into Markdown prompts.
- `languageFor(path)` maps both file extensions and leading-dot filenames (`.editorconfig` -> `ini`, `.ideavimrc`/`.vimrc` -> `viml`, `.lua` -> `lua`, `.cursorrules` -> `markdown`, `.ps1` -> `powershell`, `.sh` -> `shellscript`, `.json`/`.jsonc` -> `jsonc`). `src/lib/server/highlight.ts` preloads Shiki (`dark-plus` theme) for all mapped languages with an in-memory cache capped at 160 entries and a 300,000-character raw fallback.

---

## 3. Workbench UI Capabilities (`src/components/`)

- **Workbench & Explorer (`Workbench.tsx`, `Explorer.tsx`, `ActivityBar.tsx`, `StatusBar.tsx`):** Three views (`Explorer`, `AI Agents & Rules`, `Source Control`), category filter, folder collapse state, GitHub rate-limit status indicator, and `Ctrl/Cmd + K` shortcut.
- **File Viewer (`FileViewer.tsx`, `CodeViewer.tsx`, `JsonKeyExplorer.tsx`, `MarkdownView.tsx`):**
  - Raw server-highlighted code view vs. Rendered Markdown vs. searchable dotted-key JSON Explorer.
  - Dropdown to copy **Raw JSONC (with comments)** or **Strict JSON (comments stripped)**.
  - Multi-IDE extension quick-install bar (`buildExtensionInstallCommand` parses both `ide/extensions.txt` and `ide/extensions.json`) with an interactive CLI switcher (`code`, `agy`, `cursor`, `windsurf`, `codium`).
- **AI Agents & Rules Hub (`RulesHub.tsx`):** Splits `isAiRule: true` Markdown instruction cards (with token estimates, headings, and multi-select checkboxes) from structured Agent & MCP JSON config cards. Floating action bar concatenates selected prompts with `\n\n---\n<!-- Source: {filepath} -->\n\n`.
- **Commit History & Diff Inspector (`HistoryView.tsx`, `FileHistoryDrawer.tsx`, `CommitDetailModal.tsx`, `DiffViewer.tsx`):** Global `/history` page and per-file drawer, unified/split diff views via `parse-diff`, and per-file time-travel copy at any historical commit SHA.
- **Command Palette (`CommandPalette.tsx`):** Fuzzy search across Actions, Files, flattened JSON keys, and Markdown headings backed by `/api/repo/index`.

---

## 4. Backend API Endpoints (`src/app/api/`)

Every route handler exports `export const runtime = "nodejs"` and keeps `GITHUB_TOKEN` server-side.

| Endpoint | Query / Params | Response & Processing | Upstream Cache & Response Headers |
| :--- | :--- | :--- | :--- |
| `GET /api/repo/tree` | None | Returns `{ owner, repo, branch, latestSha, latestCommitTitle, latestCommitDate, generatedAt, files, rateLimit }` | Next.js fetch cache: `revalidate: 300` (`["repo-tree"]`); response `Cache-Control: no-store` |
| `GET /api/repo/file` | `path` (required), `ref` (optional branch/SHA), `raw=1` (optional) | Validates path in tree/commit (`400` if missing/invalid, `404` if absent). Returns raw text or `FilePayload` (Shiki HTML, stripped JSON, JSON entries, token estimate, headings, extension CLI) | Next.js fetch cache: immutable if `ref` is a 7-40 hex SHA, else `revalidate: 300` (`["repo-file", "repo-tree"]`); response `Cache-Control: public, max-age=31536000, immutable` for SHA refs, else `no-store` |
| `GET /api/repo/index` | None | Indexes up to 80 JSON/Markdown/rule files (`<= 250 KB`) with concurrency 6 for `CommandPalette` and `RulesHub` | Inherits `repo-tree` / `repo-file` cache tags; response `Cache-Control: no-store` |
| `GET /api/repo/commits` | `path` (optional), `page` (default `1`), `per_page` (default `30`, max `100`) | Paginated normalized commit summaries | Next.js fetch cache: `revalidate: 120` (`["repo-commits", "repo-tree"]`); response `Cache-Control: no-store` |
| `GET /api/repo/commits/[sha]` | Route param `sha` (7-40 hex) | Commit metadata, stats, and parsed unified diff hunks (`parse-diff`) | Next.js fetch cache: `revalidate: false` (`["repo-commits"]`); response `Cache-Control: public, max-age=31536000, immutable` |
| `POST /api/webhooks/github` | Header `x-hub-signature-256` | Verifies HMAC SHA-256 with `GITHUB_WEBHOOK_SECRET` (`503` if unset, `401` on invalid signature, `400` on invalid JSON) and expires `repo-tree`, `repo-commits`, `repo-file` | Immediate on-demand cache tag invalidation |

---

## 5. Production Deployment

1. **Build Verification:**

```bash
npm run typecheck
npm run build
npm run start
```

2. **Hosting (Vercel or Node.js Container):**
   - Set environment variables in your host dashboard: `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_DEFAULT_BRANCH` (optional), `GITHUB_TOKEN` (fine-grained read-only PAT), and `GITHUB_WEBHOOK_SECRET` (optional).
   - Ensure the Node.js runtime is enabled (do not deploy Route Handlers on Edge runtime, as `github-client.ts`, `highlight.ts`, and `crypto` webhook verification target Node.js).
3. **Optional GitHub Push Webhook:**
   - In GitHub repository **Settings -> Webhooks -> Add webhook**:
     - **Payload URL:** `https://<your-domain>/api/webhooks/github`
     - **Content type:** `application/json`
     - **Secret:** exact value of `GITHUB_WEBHOOK_SECRET`
     - **Events:** `Just the push event`
