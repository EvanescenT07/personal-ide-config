# Zed Parity Stub

Zed `settings.json` template aligning theme, delayed autosave, Prettier `format_on_save`, inline diagnostics, tab sizes, and language servers with `ide/settings.json`.

## Target Paths

- **macOS / Linux:** `~/.config/zed/settings.json`
- **Windows:** `%APPDATA%\Zed\settings.json`

## Recommended Zed Extensions

Install these extensions from Zed's Extensions panel (`zed: extensions`) for full parity with `ide/extensions.txt`:

- **Languages:** `Dart`, `Ruby`, `Dockerfile`, `Prisma`, `GitHub Actions`
- **Themes & Icons:** `Material Icon Theme` (or `Catppuccin Icons` / Zed built-in icons)

## Parity Mapping

| VS Code Setting | Zed Setting |
| :--- | :--- |
| `workbench.colorTheme: "Dark Modern"` | `"theme": { "mode": "dark", "dark": "One Dark" }` |
| `files.autoSave: "afterDelay"` | `"autosave": { "after_delay": { "milliseconds": 1000 } }` |
| `editor.formatOnSave: true` + Prettier | `"format_on_save": "on"` + `"prettier": { "allowed": true }` |
| `usernamehw.errorlens` | `"diagnostics": { "inline": { "enabled": true } }` |
| `.editorconfig` indent rules | Per-language `tab_size` and `hard_tabs` overrides under `"languages"` |
| `dart.flutterSdkPath` | `"lsp": { "dart": { "binary": { "path": "dart", ... } } }` (uses `PATH`) |
