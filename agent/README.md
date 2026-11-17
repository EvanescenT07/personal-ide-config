# AI Agent Configuration Suite

Cross-agent instructions, MCP server definitions, provider templates, skills manifests, and workspace project rules derived from a single canonical baseline.

## Canonical Rules

- [`../AGENTS.md`](../AGENTS.md): Canonical engineering rules (Sections 1-9) and machine adaptation bootstrap protocol (Section 10). Deploy this file as your global instruction baseline (for example `~/.gemini/GEMINI.md`).

## Directory Overview

| Path | Purpose | Target Location on Host |
| :--- | :--- | :--- |
| [`mcp/`](mcp/README.md) | Shared stdio and HTTP MCP server templates | `~/.gemini/config/mcp_config.json`, `~/.gemini/antigravity/mcp_config.json` |
| [`antigravity/`](antigravity/README.md) | Antigravity adapter rules, sanitized plugin/permission template, and skills pointer | `~/.gemini/` |
| [`opencode/`](opencode/README.md) | OpenCode provider/MCP configuration, rules, and plugin manifest | `~/.config/opencode/` |
| [`commandcode/`](commandcode/README.md) | CommandCode provider configuration and plugin manifest | `~/.opencode/` |
| [`skills/`](skills/README.md) | Lockfile, unified skills/plugins catalog, and `ide-config-adapter` skill | `~/.agents/skills/` |
| [`workspace/`](workspace/README.md) | Reusable `.agents/` template for project repositories | `<project-root>/.agents/` |

## Adaptation & Deployment Workflow

1. **Automated Deployment:** Run `scripts/deploy-configs.ps1` (Windows) or `scripts/deploy-configs.sh` (macOS/Linux) to back up existing files and copy templates into OS-specific user directories.
2. **AI-Driven Adaptation:** Point any coding agent at [`../AGENTS.md`](../AGENTS.md) and [`skills/ide-config-adapter/SKILL.md`](skills/ide-config-adapter/SKILL.md) so it inspects your host OS, installed IDEs, and SDK binaries, then merges `ide/` and `agent/` templates without overwriting live secrets or machine-specific settings.
3. **Environment Secrets:** Export required tokens locally (`CONTEXT7_API_KEY`, `STITCH_API_KEY`, `GITHUB_TOKEN`, `COMMANDCODE_API_KEY`) rather than hardcoding secrets into repository files.
