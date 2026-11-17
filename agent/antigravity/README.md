# Antigravity Agent Configuration

Templates and adapters for Google Antigravity global user configuration under `~/.gemini/` (`%USERPROFILE%\.gemini\` on Windows).

## Files & Host Targets

| Repo File | Host Target | Deployment Strategy |
| :--- | :--- | :--- |
| [`../../AGENTS.md`](../../AGENTS.md) | `~/.gemini/GEMINI.md` | Copy or symlink (canonical global rules) |
| [`GEMINI.md`](GEMINI.md) | Reference only | Pointer adapter inside repo to avoid duplicating `AGENTS.md` |
| [`config.template.json`](config.template.json) | `~/.gemini/config/config.json` | Manual merge only; never overwrite live `config.json` blindly |
| [`skills.json`](skills.json) | `~/.gemini/config/skills.json` | Copy and resolve `${HOME}` to your absolute user home path |
| [`../mcp/mcp_config.json`](../mcp/mcp_config.json) | `~/.gemini/config/mcp_config.json` | Copy and supply local env vars (`CONTEXT7_API_KEY`, `STITCH_API_KEY`) |

## Excluded Runtime & Machine State

The following files are intentionally excluded from version control and must never be committed:

- `antigravity_state.pbtxt`: Local onboarding flags, `installation_uuid`, and migration state.
- Live `~/.gemini/config/config.json`: Contains machine-specific `remoteControlHostname`, plugin `installedFrom` install metadata, and local project `read_file(...)` permission grants.
- `~/.gemini/config/projects/*.json`: Per-machine workspace paths, worktree URIs, and approval policies.
- OAuth credentials and plugin session tokens.
