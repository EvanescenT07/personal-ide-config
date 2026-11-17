# CommandCode Configuration

Global CommandCode provider configuration template targeting `~/.opencode/` (`%USERPROFILE%\.opencode\` on Windows).

## Files

| Repo File | Target Path | Purpose |
| :--- | :--- | :--- |
| [`opencode.jsonc`](opencode.jsonc) | `~/.opencode/opencode.jsonc` | Registers `commandcode` OpenAI-compatible provider (`commandcode/gpt-4o`), local skills path, and MCP servers (`context7`, `playwright`) |
| [`package.json`](package.json) | `~/.opencode/package.json` | Pins `@opencode-ai/plugin` (`1.18.12`) |

## Setup Notes

1. Deploy files using `scripts/deploy-configs.ps1 -Target commandcode` or `scripts/deploy-configs.sh --target commandcode`.
2. Export `COMMANDCODE_API_KEY` in your shell environment before starting the client.
3. If your local runtime does not expand `~` inside `skills.paths`, replace `"~/.opencode/skills"` in the deployed copy with your absolute home path using forward slashes (e.g. from `$HOME` on POSIX or `$env:USERPROFILE` on Windows).
4. Run `npm install` (or `bun install`) inside `~/.opencode/` if plugin dependencies are required locally.
