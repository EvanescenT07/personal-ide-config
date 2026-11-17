# Shared MCP Server Templates

Model Context Protocol (MCP) server definitions sanitized with environment variable placeholders.

## Files

- [`mcp_config.json`](mcp_config.json): Full stdio + HTTP server bundle (`context7`, `graphify`, `playwright`, `stitch`, `rea`, `flow-connector`, `dart-mcp-server`). Deploy to `~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity/mcp_config.json`.
- [`mcp_config_http.json`](mcp_config_http.json): Remote HTTP-only subset (`context7`, `stitch`) for IDE or lightweight environments where local Node.js or Python `uv` runtimes are unavailable.

## Required Environment Variables & Prerequisites

| Server | Transport | Runtime / Binary | Required Env Var |
| :--- | :--- | :--- | :--- |
| `context7` | stdio (`@upstash/context7-mcp@latest`) or HTTP | `node` / `npx` (stdio) | `CONTEXT7_API_KEY` |
| `stitch` | HTTP (`https://stitch.googleapis.com/mcp`) | Network HTTPS | `STITCH_API_KEY` |
| `graphify` | stdio (`graphifyy` + `mcp`) | `uv` (Python) | None |
| `playwright` | stdio (`@playwright/mcp@latest`) | `node` / `npx` | None |
| `rea` | stdio (`rea-agents@6.8.0 mcp`) | `node` / `npx` | None |
| `flow-connector` | stdio | `flow-auto-mcp` on `PATH` | None |
| `dart-mcp-server` | stdio (`dart mcp-server`) | Dart SDK (`dart`) | None |

## Cross-Platform Execution Notes

- **macOS and Linux:** Keep `"command": "npx"` directly for `context7`, `playwright`, and `rea`.
- **Windows:** GUI-spawned MCP hosts on Windows sometimes fail to resolve `.cmd` batch shims when given bare `"npx"`. If a stdio Node server fails to start on Windows:
  - Use `"command": "npx.cmd"` (commonly needed for `context7`), or
  - Wrap with `"command": "cmd.exe"` and `"args": ["/d", "/c", "npx", "-y", "rea-agents@6.8.0", "mcp"]` for `rea`.
- **Placeholder Expansion:** Some MCP clients do not expand `${env:...}` inside JSON `args` or `headers` arrays. During local deployment, substitute secrets only in your local `~/.gemini/` copy and never commit resolved keys back to git.
- **`dart-mcp-server` Schema Field:** `$typeName` (`exa.cascade_plugins_pb.CascadePluginCommandTemplate`) is Antigravity plugin template metadata. Non-Antigravity MCP hosts either ignore it or require removing that key.
