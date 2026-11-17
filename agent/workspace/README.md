# Workspace Project Template (`.agents/`)

Project-level agent rules, workflows, and skills pointer designed to be copied into `<project-root>/.agents/`.

## Contents

- [`skills.json`](skills.json): Workspace skills directory pointer (`${HOME}/.agents/skills`).
- [`rules/graphify.md`](rules/graphify.md): Always-on rule instructing agents to query `graphify-out/` before reading raw files.
- [`workflows/graphify.md`](workflows/graphify.md): Slash workflow `/graphify` definition.

## Deployment

Deploy into a project repository via script:

```powershell
# Windows PowerShell
.\scripts\deploy-configs.ps1 -Target workspace -WorkspacePath path/to/your-project -ResolvePaths
```

```bash
# macOS / Linux
./scripts/deploy-configs.sh --target workspace --workspace path/to/your-project
```

If your host agent does not expand `${HOME}` in `.agents/skills.json`, use `-ResolvePaths` (or `agent/skills/ide-config-adapter`) to substitute your local home directory in the deployed project copy.
