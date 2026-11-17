# Documentation Index

Reference guides for the Universal IDE + AI Agent Config Kit and the Next.js IDE Config & AI Agent Hub.

## Reading Paths

Choose the track matching your current goal:

1. **Setting up a new workstation manually (scripts):**
   - [IDE Migration Guide](ide-migration.md) -> [AI Agents & MCP Guide](ai-agents.md) -> [Security & Secret Hygiene](security.md)
2. **Having an AI coding agent configure your machine:**
   - [Agent Self-Adaptation Playbook](agent-adaptation.md) -> [Security & Secret Hygiene](security.md)
3. **Developing, customizing, or hosting the Next.js web workbench:**
   - [Architecture Overview](architecture.md) -> [Web Hub Guide](web-hub.md) -> [Security & Secret Hygiene](security.md)

## Document Catalog

| Document | Scope | Audience |
| :--- | :--- | :--- |
| [architecture.md](architecture.md) | Design principles, directory separation (`ide/`, `agent/`, `scripts/`, `docs/`, `src/`), and Next.js data flow | Maintainers and contributors |
| [ide-migration.md](ide-migration.md) | VS Code, Antigravity, Cursor, Windsurf, VSCodium parity, `.editorconfig`, 27-extension stack, and JetBrains/Neovim/Zed stubs | All developers |
| [ai-agents.md](ai-agents.md) | Canonical `AGENTS.md` rules, Antigravity, OpenCode, CommandCode, 7 MCP servers, skills/plugins, and `.agents/` template | AI-assisted developers |
| [agent-adaptation.md](agent-adaptation.md) | Step-by-step workflow for passing this repo to any AI agent using `ide-config-adapter` | Workstation setup via AI |
| [security.md](security.md) | Secret sanitization rules, required environment variables, server-only web hub guarantees, and pre-push audit commands | All contributors |
| [web-hub.md](web-hub.md) | Next.js hub `.env` setup, dynamic tree classifier rules, workbench UI features, API endpoints, and hosting | Web hub operators |

## Related Component Docs

- [`../AGENTS.md`](../AGENTS.md): Canonical engineering rules (Sections 1-9) and machine adaptation bootstrap (Section 10).
- [`../PRD - IDE Config & AI Agent Hub.md`](../PRD%20-%20IDE%20Config%20%26%20AI%20Agent%20Hub.md): Product requirements and implemented web hub specification.
- [`../ide/README.md`](../ide/README.md): Quick reference inside `ide/` for VS Code-family paths and stubs.
- [`../agent/README.md`](../agent/README.md): Directory summary inside `agent/` for agent templates and MCP servers.
- [`../scripts/README.md`](../scripts/README.md): Complete CLI flag reference for `.ps1` and `.sh` scripts.
