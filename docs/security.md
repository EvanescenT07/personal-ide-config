# Security & Secret Hygiene

Rules, environment variables, web hub security invariants, and pre-push verification commands keeping secrets and personal paths out of git.

---

## 1. Sanitization Rules

Tracked files under `ide/`, `agent/`, `scripts/`, `docs/`, and `src/` must never contain:

- Live API keys, Personal Access Tokens, or webhook secrets (raw `ghp_`, `github_pat_`, or provider API key literals instead of placeholders).
- Machine-local home paths (`C:\Users\<name>`, `/Users/<name>`, `/home/<name>`) or local SDK installation paths.
- Runtime onboarding or project state (`antigravity_state.pbtxt`, live `~/.gemini/config/config.json`, `~/.gemini/config/projects/*.json`, `.env`, `.env.local`).

Instead, templates use standard placeholders:

- `${env:VAR_NAME}` in `ide/settings.json` and `agent/mcp/mcp_config*.json`
- `{env:VAR_NAME}` in OpenCode configs (`agent/opencode/opencode.jsonc`) for native runtime expansion
- `${HOME}` in `agent/antigravity/skills.json` and `agent/workspace/skills.json`

When deploying with `scripts/deploy-configs.ps1 -ResolvePaths` or `scripts/deploy-configs.sh --resolve-paths`:

- Only external host copies are modified (`%APPDATA%`, `~/.config`, `~/.gemini`, `~/.opencode`, `<workspace>/.agents`).
- `${HOME}`, `${env:FLUTTER_ROOT}`, `${env:JAVA_HOME}`, and any already-set `${env:*}` variables are resolved into deployed JSON/JSONC files, skipping `//` comment lines.
- Unset secret placeholders remain intact, and resolved secret values are never printed to stdout.

---

## 2. Environment Variables Reference

### Local Workstation & Agent Secrets

| Variable | Consumed By | Purpose |
| :--- | :--- | :--- |
| `SOURCERY_TOKEN` | Deployed `User/settings.json` (`sourcery.token`) | Sourcery code analysis token |
| `CONTEXT7_API_KEY` | `~/.gemini/config/mcp_config.json`, `mcp_config_http.json` | Context7 MCP documentation server auth |
| `STITCH_API_KEY` | `~/.gemini/config/mcp_config.json`, `mcp_config_http.json` | Google Stitch MCP `X-Goog-Api-Key` header |
| `COMMANDCODE_API_KEY` | `~/.opencode/opencode.jsonc` | CommandCode OpenAI-compatible API key |
| `GITHUB_TOKEN` | `~/.config/opencode/opencode.jsonc` (`{env:GITHUB_TOKEN}` -> `GITHUB_PERSONAL_ACCESS_TOKEN`) and Web Hub server | GitHub MCP server and authenticated GitHub REST API requests |

### Web Hub Server Environment (`.env` / `.env.local`)

| Variable | Required | Default / Behavior |
| :--- | :--- | :--- |
| `GITHUB_OWNER` | Optional | Defaults to `"EvanescenT07"` in `src/lib/server/github-client.ts` |
| `GITHUB_REPO` | Optional | Defaults to `"vscode-config"` (update in `.env.local` if renamed on GitHub) |
| `GITHUB_DEFAULT_BRANCH` | Optional | Auto-detected via `GET /repos/{owner}/{repo}` if omitted |
| `GITHUB_TOKEN` | Optional | Fine-grained read-only PAT raising GitHub REST rate limit from 60 to 5,000 req/hr |
| `GITHUB_WEBHOOK_SECRET` | Optional | HMAC SHA-256 secret verifying `POST /api/webhooks/github` (`503` returned if unset) |

### Non-Secret SDK Placeholders (`ide/settings.json`)

| Variable | Purpose |
| :--- | :--- |
| `FLUTTER_ROOT` | Local Flutter SDK root (`dart.flutterSdkPath`) |
| `JAVA_HOME` | Local JDK / Android Studio JBR root (`java.jdt.ls.java.home`) |

---

## 3. Web Hub Security Invariants (`src/`)

1. **Server-Only Token Isolation:** `GITHUB_TOKEN` and `GITHUB_WEBHOOK_SECRET` are never prefixed with `NEXT_PUBLIC_` and are accessed solely inside `"server-only"` modules (`src/lib/server/github-client.ts`) or Node.js Route Handlers (`src/app/api/webhooks/github/route.ts`).
2. **Least-Privilege GitHub PAT:** Grant a Fine-Grained Personal Access Token **Read-Only** access to **Contents** and **Metadata** on the target repository only.
3. **Path & Ref Validation:** `normalizeRepoPath`, `normalizeRef`, and `assertPathAccessible` (`src/lib/server/repo-service.ts`) reject leading slashes, null bytes, `..` traversal segments, and any path not present in the Git tree or commit file list before fetching from `raw.githubusercontent.com`.
4. **Constant-Time Webhook Verification:** `POST /api/webhooks/github` computes `sha256=` HMAC digests and verifies `X-Hub-Signature-256` with `crypto.timingSafeEqual` after length validation.

---

## 4. Pre-Push Audit Commands

Run these read-only checks before committing or pushing to a public or shared repository:

**Windows (PowerShell):**

```powershell
# 1. Confirm .env files are ignored and untracked
git status --short
git check-ignore -v .env .env.local

# 2. Scan tracked files for raw token prefixes or local user home paths
git grep -nE "ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]+|Bearer [A-Za-z0-9._-]{16,}|C:\\Users\\|/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/"
```

**macOS / Linux (Bash):**

```bash
# 1. Confirm .env files are ignored and untracked
git status --short
git check-ignore -v .env .env.local

# 2. Scan tracked files for raw token prefixes or local user home paths
git grep -nE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]+|Bearer [A-Za-z0-9._-]{16,}|C:\\Users\\|/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/'
```

Expected result for `git grep`: zero matches (exit code `1`). If any match appears outside `.env.example` placeholder examples or documentation regex examples, replace the literal with `${env:...}` or `${HOME}` and rotate the exposed credential immediately.
