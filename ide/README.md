# Global IDE Configuration & Parity Guide

Centralized editor settings, curated extension stack, and non-VS Code parity stubs designed for consistent workflows across machines and editors.

## Contents

- [../.editorconfig](../.editorconfig): Cross-IDE formatting baseline (UTF-8, LF line endings, language-specific indentation).
- [settings.json](settings.json): Global VS Code-family user settings (JSONC) with sanitized placeholders.
- [extensions.txt](extensions.txt): Curated 27-extension list grouped by category.
- [extensions.json](extensions.json): Workspace `.vscode/extensions.json` recommendations template.
- [stubs/](stubs/): Starter parity configs for JetBrains IDEs, Neovim, and Zed.

## VS Code-Family Parity Matrix

`ide/settings.json` and `ide/extensions.txt` target all major VS Code-compatible editors:

| IDE | CLI Binary | Windows User Settings | macOS User Settings | Linux User Settings |
| :--- | :--- | :--- | :--- | :--- |
| Visual Studio Code | `code` | `%APPDATA%\Code\User\settings.json` | `~/Library/Application Support/Code/User/settings.json` | `~/.config/Code/User/settings.json` |
| Google Antigravity | `agy` | `%APPDATA%\Antigravity\User\settings.json` | `~/Library/Application Support/Antigravity/User/settings.json` | `~/.config/Antigravity/User/settings.json` |
| Cursor | `cursor` | `%APPDATA%\Cursor\User\settings.json` | `~/Library/Application Support/Cursor/User/settings.json` | `~/.config/Cursor/User/settings.json` |
| Windsurf | `windsurf` | `%APPDATA%\Windsurf\User\settings.json` | `~/Library/Application Support/Windsurf/User/settings.json` | `~/.config/Windsurf/User/settings.json` |
| VSCodium | `codium` | `%APPDATA%\VSCodium\User\settings.json` | `~/Library/Application Support/VSCodium/User/settings.json` | `~/.config/VSCodium/User/settings.json` |

### Open VSX Registry Note

VS Code uses the Microsoft Marketplace, whereas Antigravity, Cursor, Windsurf, and VSCodium pull from Open VSX or hybrid registries. Most extensions in `ide/extensions.txt` resolve identically across all five editors, though Microsoft-restricted extensions (or niche releases) may require installing a `.vsix` manually on Open VSX forks.

## Deployment & Installation

Use the cross-platform scripts in `scripts/` rather than editing target directories by hand:

```powershell
# Windows PowerShell: install missing extensions and deploy settings with SDK path resolution
.\scripts\install-extensions.ps1 -Ide auto -Mode missing
.\scripts\deploy-configs.ps1 -Target ide -Ide auto -ResolvePaths
```

```bash
# macOS / Linux: install missing extensions and deploy settings
./scripts/install-extensions.sh --ide auto --missing
./scripts/deploy-configs.sh --target ide --ide auto
```

For project-level contributor prompts, copy `ide/extensions.json` to `<your-project>/.vscode/extensions.json`.

## SDK & Secret Placeholder Adaptation

`ide/settings.json` stores portable placeholders instead of machine-local paths or personal tokens:

| Key | Placeholder | Expected Local Value |
| :--- | :--- | :--- |
| `sourcery.token` | `${env:SOURCERY_TOKEN}` | Personal Sourcery token (keep out of git) |
| `dart.flutterSdkPath` | `${env:FLUTTER_ROOT}` | Local Flutter SDK root (for example `~/dev/flutter` or `C:\dev\flutter`) |
| `java.jdt.ls.java.home` | `${env:JAVA_HOME}` | Local JDK / JBR home directory |

VS Code user `settings.json` does not expand `${env:...}` variables inside most extension settings. After copying `ide/settings.json` to your local User folder, resolve these placeholders in one of three ways:

1. Run `scripts/deploy-configs.ps1 -ResolvePaths` to detect `flutter` and `java` on `PATH` and substitute `${env:FLUTTER_ROOT}` and `${env:JAVA_HOME}` in the deployed copy.
2. Point an AI agent at `agent/skills/ide-config-adapter/SKILL.md` to inspect your OS and SDK paths and merge the settings safely.
3. Edit the deployed local `settings.json` directly with your machine paths and token. Never commit resolved tokens or personal paths back to this repository.

## Non-VS Code Stubs

If you also work outside VS Code-family editors, see the parity stubs under `ide/stubs/`:

- [JetBrains IDEs](stubs/jetbrains/README.md): `.ideavimrc` and plugin/settings mapping for IntelliJ IDEA, Android Studio, PyCharm, and GoLand.
- [Neovim](stubs/neovim/README.md): Minimal `init.lua` starter with `conform.nvim`, LSPs, `telescope.nvim`, and `gitsigns.nvim`.
- [Zed](stubs/zed/README.md): `settings.json` JSONC mapping theme, autosave, `format_on_save`, tab sizes, and language servers.
