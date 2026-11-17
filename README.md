# IDE Config & AI Agent Hub

Centralized development environment configuration kit and Next.js workbench hub built around two pillars:

1. **Universal IDE + AI Agent Config & Migration Kit** ([`AGENTS.md`](AGENTS.md), [`.editorconfig`](.editorconfig), [`ide/`](ide/README.md), [`agent/`](agent/README.md), [`scripts/`](scripts/README.md)): Sanitized global editor settings, a curated 27-extension stack, non-VS Code editor stubs, canonical AI engineering rules, shared MCP server definitions, skills manifests, and cross-platform deployment scripts with timestamped backups.
2. **Next.js IDE Config & AI Agent Hub** ([`src/`](src/app/page.tsx)): An IDE-inspired web workbench (`ide-config-hub`) backed by a Node.js GitHub API pipeline that auto-classifies repository blobs, strips JSONC comments, indexes JSON keys, combines Markdown AI prompts, and inspects commit history and diffs.

---

## Repository Structure

```text
.
├── .editorconfig                        # Cross-IDE formatting baseline (UTF-8, LF, per-language indent)
├── .env.example                         # Web hub GitHub repository, PAT, and webhook environment template
├── AGENTS.md                            # Canonical AI agent engineering rules (Sections 1-9) & bootstrap (Section 10)
├── PRD - IDE Config & AI Agent Hub.md   # Product & technical specification for the config kit and web hub
├── README.md                            # Top-level guide and quick start
├── package.json                         # Next.js web hub manifest ("ide-config-hub")
│
├── ide/                                 # Global IDE settings, extensions, and non-VS Code parity stubs
│   ├── README.md                        # VS Code-family parity matrix, OS paths, and SDK placeholder guide
│   ├── settings.json                    # Sanitized JSONC user settings (29 keys across editors/languages)
│   ├── extensions.txt                   # Curated 27-extension ID list grouped by category
│   ├── extensions.json                  # Workspace .vscode/extensions.json recommendations template
│   └── stubs/
│       ├── jetbrains/                   # .ideavimrc & JetBrains IDE plugin/settings mapping
│       ├── neovim/                      # Minimal Neovim (0.10+) init.lua stub (conform, LSP, telescope, gitsigns)
│       └── zed/                         # Zed settings.json (JSONC) & extension parity notes
│
├── agent/                               # AI agent instructions, MCP templates, provider configs, and skills
│   ├── README.md                        # Agent config architecture and target host mapping
│   ├── antigravity/                     # GEMINI.md adapter, config.template.json, skills.json
│   ├── commandcode/                     # CommandCode opencode.jsonc & package.json
│   ├── mcp/                             # mcp_config.json (7 servers) & mcp_config_http.json (HTTP subset)
│   ├── opencode/                        # OpenCode opencode.jsonc, rules.md, package.json
│   ├── skills/                          # .skill-lock.json, manifest.json, ide-config-adapter/SKILL.md
│   └── workspace/                       # Reusable .agents/ project template (skills.json, rules, workflows)
│
├── scripts/                             # Cross-platform installation & deployment automation
│   ├── README.md                        # CLI flags, target path matrix, and backup/placeholder safety guide
│   ├── install-extensions.ps1           # Windows PowerShell multi-IDE extension installer
│   ├── install-extensions.sh            # macOS/Linux Bash multi-IDE extension installer
│   ├── deploy-configs.ps1               # Windows PowerShell config deployer with backups & -ResolvePaths
│   └── deploy-configs.sh                # macOS/Linux Bash config deployer with backups & --resolve-paths
│
├── docs/                                # Detailed operational documentation
│   ├── README.md                        # Documentation index and reading paths
│   ├── architecture.md                  # Repository design philosophy & Next.js pipeline data flow
│   ├── ide-migration.md                 # Cross-IDE setup, 27-extension stack, and editor stubs
│   ├── ai-agents.md                     # AGENTS.md, Antigravity, OpenCode, CommandCode, MCP, Skills, .agents/
│   ├── agent-adaptation.md              # Playbook for AI-driven workstation inspection & config merging
│   ├── security.md                      # Secret sanitization rules, required env vars, and pre-push audits
│   └── web-hub.md                       # Next.js hub setup, classifier heuristics, API routes, deployment
│
└── src/                                 # Next.js App Router + Node.js runtime web workbench
    ├── app/                             # App Router pages (/, /history) and /api/* Route Handlers
    ├── components/                      # Workbench, FileViewer, RulesHub, History/Diff, CommandPalette UI
    ├── lib/                             # Server GitHub/classifier/JSONC/diff/Shiki pipeline & client helpers
    └── types/                           # Ambient type declarations (parse-diff)
```

---

## Quick Start

### 1. IDE Extensions & Settings

Preview actions with dry-run flags before writing to local IDE directories. Existing `settings.json` files are automatically backed up to `settings.json.bak.<YYYYMMDD-HHmmss>`.

**Windows (PowerShell):**

```powershell
# Install missing extensions from ide/extensions.txt across all detected IDEs
.\scripts\install-extensions.ps1 -Ide auto -Mode missing -DryRun
.\scripts\install-extensions.ps1 -Ide auto -Mode missing

# Deploy ide/settings.json and resolve detected FLUTTER_ROOT / JAVA_HOME / HOME paths
.\scripts\deploy-configs.ps1 -Target ide -Ide auto -ResolvePaths -DryRun
.\scripts\deploy-configs.ps1 -Target ide -Ide auto -ResolvePaths
```

**macOS / Linux (Bash):**

```bash
chmod +x scripts/*.sh

# Install missing extensions across all detected IDEs
./scripts/install-extensions.sh --ide auto --missing --dry-run
./scripts/install-extensions.sh --ide auto --missing

# Deploy ide/settings.json and resolve detected SDK/home paths
./scripts/deploy-configs.sh --target ide --ide auto --resolve-paths --dry-run
./scripts/deploy-configs.sh --target ide --ide auto --resolve-paths
```

For full details (including `ide/extensions.json`, `.editorconfig`, and JetBrains/Neovim/Zed stubs), see [docs/ide-migration.md](docs/ide-migration.md).

### 2. AI Agents & MCP Servers

Deploy global agent rules ([`AGENTS.md`](AGENTS.md)), MCP definitions ([`agent/mcp/mcp_config.json`](agent/mcp/mcp_config.json)), and provider templates ([`agent/antigravity/`](agent/antigravity/README.md), [`agent/opencode/`](agent/opencode/README.md), [`agent/commandcode/`](agent/commandcode/README.md)):

```powershell
# Windows: deploy all global agent targets (skips workspace when run inside this repo root)
.\scripts\deploy-configs.ps1 -Target all -Ide auto -ResolvePaths -DryRun
.\scripts\deploy-configs.ps1 -Target all -Ide auto -ResolvePaths

# Deploy project-level .agents/ rules and workflows into a specific codebase
.\scripts\deploy-configs.ps1 -Target workspace -WorkspacePath D:\Projects\my-app -ResolvePaths
```

```bash
# macOS / Linux: deploy all global agent targets
./scripts/deploy-configs.sh --target all --ide auto --resolve-paths --dry-run
./scripts/deploy-configs.sh --target all --ide auto --resolve-paths

# Deploy project-level .agents/ template into a project repository
./scripts/deploy-configs.sh --target workspace --workspace ~/projects/my-app --resolve-paths
```

After deploying templates:

- Export required environment variables locally (`SOURCERY_TOKEN`, `CONTEXT7_API_KEY`, `STITCH_API_KEY`, `COMMANDCODE_API_KEY`, `GITHUB_TOKEN`) or populate them in your deployed host configs only (never in this repository).
- Merge plugins/permissions manually into live `~/.gemini/config/config.json` using the deployed `config.template.json` (`deploy-configs` never overwrites `config.json` automatically).
- Restore lockfile skills globally via `npx skills add <owner/repo> --skill <name> -g -y` using [`agent/skills/manifest.json`](agent/skills/manifest.json).

See [docs/ai-agents.md](docs/ai-agents.md) for the complete breakdown.

### 3. Agent Self-Adaptation

You can hand this repository directly to any AI coding agent (Antigravity, Claude Code, OpenCode, CommandCode, Cursor, or Codex) to configure a workstation automatically. Section 10 of [`AGENTS.md`](AGENTS.md) instructs the agent to load [`agent/skills/ide-config-adapter/SKILL.md`](agent/skills/ide-config-adapter/SKILL.md), inspect your OS, IDE binaries, and local SDK paths (`flutter`, `java`, `python`, `uv`, `node`, `dart`, `go`) in read-only mode first, confirm targets with you, create timestamped backups, and merge settings safely without leaking secrets.

Example prompt:

```text
Read AGENTS.md and agent/skills/ide-config-adapter/SKILL.md. Inspect my OS, installed IDEs, AI agent directories, and SDK paths in read-only mode first, then show me a dry-run adaptation plan before applying any changes.
```

See [docs/agent-adaptation.md](docs/agent-adaptation.md) for the full playbook.

### 4. Web Hub (`src/`)

Run the Next.js Config & AI Agent Hub locally:

```bash
npm install
cp .env.example .env.local   # PowerShell: Copy-Item .env.example .env.local
```

Configure `.env.local` (set `GITHUB_OWNER`, `GITHUB_REPO`, optional `GITHUB_DEFAULT_BRANCH`, and optional read-only `GITHUB_TOKEN` to raise the GitHub API limit from 60 to 5,000 requests/hour), then start the dev server:

```bash
npm run dev
```

See [docs/web-hub.md](docs/web-hub.md) for classifier heuristics, API endpoints, and production deployment.

---

## Supported IDEs & Agents

| Tool | Category | CLI / Entry | Config Source in Repo | Target Host Location |
| :--- | :--- | :--- | :--- | :--- |
| Visual Studio Code | IDE | `code` | `ide/settings.json`, `ide/extensions.txt` | `%APPDATA%\Code\User\` / `~/Library/Application Support/Code/User/` / `~/.config/Code/User/` |
| Google Antigravity IDE | IDE | `agy` | `ide/settings.json`, `ide/extensions.txt` | `%APPDATA%\Antigravity\User\` / `~/Library/Application Support/Antigravity/User/` / `~/.config/Antigravity/User/` |
| Cursor | IDE | `cursor` | `ide/settings.json`, `ide/extensions.txt` | `%APPDATA%\Cursor\User\` / `~/Library/Application Support/Cursor/User/` / `~/.config/Cursor/User/` |
| Windsurf | IDE | `windsurf` | `ide/settings.json`, `ide/extensions.txt` | `%APPDATA%\Windsurf\User\` / `~/Library/Application Support/Windsurf/User/` / `~/.config/Windsurf/User/` |
| VSCodium | IDE | `codium` | `ide/settings.json`, `ide/extensions.txt` | `%APPDATA%\VSCodium\User\` / `~/Library/Application Support/VSCodium/User/` / `~/.config/VSCodium/User/` |
| JetBrains IDEs | IDE Stub | `idea` / `studio` | `ide/stubs/jetbrains/.ideavimrc` | `~/.ideavimrc` (`%USERPROFILE%\.ideavimrc` on Windows) |
| Neovim (`>= 0.10`) | IDE Stub | `nvim` | `ide/stubs/neovim/init.lua` | `~/.config/nvim/init.lua` / `%LOCALAPPDATA%\nvim\init.lua` |
| Zed | IDE Stub | `zed` | `ide/stubs/zed/settings.json` | `~/.config/zed/settings.json` / `%APPDATA%\Zed\settings.json` |
| Antigravity Agent | AI Agent | `agy` | `AGENTS.md`, `agent/antigravity/`, `agent/mcp/` | `~/.gemini/GEMINI.md`, `~/.gemini/config/` |
| OpenCode | AI Agent | `opencode` | `agent/opencode/*` | `~/.config/opencode/` |
| CommandCode | AI Agent | `opencode` | `agent/commandcode/*` | `~/.opencode/` |
| Project `.agents/` | Workspace | Any agent | `agent/workspace/*` | `<project-root>/.agents/` |
| Claude Code / Codex / Copilot | AI Agent | CLI / IDE | `AGENTS.md`, `.editorconfig` | Project root or user global rules |

---

## Documentation Index

| Document | Purpose |
| :--- | :--- |
| [docs/README.md](docs/README.md) | Documentation table of contents and reading order |
| [docs/architecture.md](docs/architecture.md) | Repository design, separation of concerns, and Next.js hub data flow |
| [docs/ide-migration.md](docs/ide-migration.md) | Cross-IDE setup, `.editorconfig`, 27-extension stack, and editor stubs |
| [docs/ai-agents.md](docs/ai-agents.md) | `AGENTS.md`, Antigravity, OpenCode, CommandCode, MCP servers, skills, `.agents/` |
| [docs/agent-adaptation.md](docs/agent-adaptation.md) | AI-driven host inspection and config merge playbook (`ide-config-adapter`) |
| [docs/security.md](docs/security.md) | Placeholder rules, required env vars, web hub invariants, pre-push audits |
| [docs/web-hub.md](docs/web-hub.md) | Next.js hub setup, classifier heuristics, API endpoints, deployment |
