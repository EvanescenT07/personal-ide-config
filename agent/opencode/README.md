# OpenCode Configuration

Global OpenCode CLI/IDE configuration templates targeting `~/.config/opencode/` (`%USERPROFILE%\.config\opencode\` on Windows).

## Files

| Repo File | Target Path | Purpose |
| :--- | :--- | :--- |
| [`opencode.jsonc`](opencode.jsonc) | `~/.config/opencode/opencode.jsonc` | Default model (`interpreter/sonnet-4.5`), rules pointer, and MCP servers (`github`, `rea`) |
| [`rules.md`](rules.md) | `~/.config/opencode/rules.md` | Global engineering rules kept in parity with [`../../AGENTS.md`](../../AGENTS.md) |
| [`package.json`](package.json) | `~/.config/opencode/package.json` | Pins `@opencode-ai/plugin` (`1.18.5`) |

## Setup Notes

1. Deploy files using `scripts/deploy-configs.ps1 -Target opencode` or `scripts/deploy-configs.sh --target opencode`.
2. Export `GITHUB_TOKEN` in your shell environment so `mcp.github` resolves `{env:GITHUB_TOKEN}` at runtime.
3. Run `npm install` (or `bun install`) inside `~/.config/opencode/` if OpenCode plugins need local package resolution.
4. On Windows, if `mcp.rea` fails to spawn via bare `"npx"`, replace `"command"` in your local `~/.config/opencode/opencode.jsonc` with `["cmd.exe", "/d", "/c", "npx", "-y", "rea-agents@6.8.0", "mcp"]`.
