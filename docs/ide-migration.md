# IDE Migration Guide

Standardized editor settings, curated 27-extension stack, cross-IDE formatting rules, and parity stubs for non-VS Code editors.

---

## 1. Universal Baseline (`.editorconfig`)

Place or inherit [`.editorconfig`](../.editorconfig) at the root of projects for consistent whitespace and encoding across VS Code-family editors, JetBrains IDEs, Neovim, and Zed:

- **Default (`[*]`):** UTF-8 charset, `lf` line endings, 2-space indentation, final newline inserted, trailing whitespace trimmed.
- **2-space languages:** `ts`, `tsx`, `js`, `jsx`, `mjs`, `cjs`, `json`, `jsonc`, `yaml`, `yml`, `css`, `scss`, `html`, `svg`, `prisma`, `dart`.
- **Python (`*.py`):** 4 spaces.
- **Go (`*.go`) and `Makefile`:** Tabs (`indent_size = 4` for Go).
- **Shell (`*.sh`, `*.bash`, `*.zsh`):** 2 spaces, `lf` line endings.
- **PowerShell (`*.ps1`, `*.psm1`, `*.psd1`):** 4 spaces.
- **Batch (`*.bat`, `*.cmd`):** 2 spaces, `crlf` line endings.
- **Markdown (`*.md`, `*.mdx`, `*.mdc`):** 2 spaces, `trim_trailing_whitespace = false` (preserves intentional hard line breaks).

---

## 2. VS Code-Family Parity Matrix

[`ide/settings.json`](../ide/settings.json) and [`ide/extensions.txt`](../ide/extensions.txt) target all five VS Code-compatible editors:

| IDE Key | Editor | CLI Binary | Windows `User\settings.json` | macOS `User/settings.json` | Linux `User/settings.json` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `vscode` | Visual Studio Code | `code` | `%APPDATA%\Code\User\settings.json` | `~/Library/Application Support/Code/User/settings.json` | `~/.config/Code/User/settings.json` |
| `antigravity` | Google Antigravity | `agy` | `%APPDATA%\Antigravity\User\settings.json` | `~/Library/Application Support/Antigravity/User/settings.json` | `~/.config/Antigravity/User/settings.json` |
| `cursor` | Cursor | `cursor` | `%APPDATA%\Cursor\User\settings.json` | `~/Library/Application Support/Cursor/User/settings.json` | `~/.config/Cursor/User/settings.json` |
| `windsurf` | Windsurf | `windsurf` | `%APPDATA%\Windsurf\User\settings.json` | `~/Library/Application Support/Windsurf/User/settings.json` | `~/.config/Windsurf/User/settings.json` |
| `codium` | VSCodium | `codium` | `%APPDATA%\VSCodium\User\settings.json` | `~/Library/Application Support/VSCodium/User/settings.json` | `~/.config/VSCodium/User/settings.json` |

On Linux, `scripts/deploy-configs.sh` respects `$XDG_CONFIG_HOME` when defined and falls back to `~/.config`.

### Open VSX vs. Microsoft Marketplace

VS Code queries the Microsoft Marketplace, whereas Antigravity, Cursor, Windsurf, and VSCodium use Open VSX or hybrid registries. Most IDs in `ide/extensions.txt` install identically across all five editors. If a Microsoft-restricted extension fails on an Open VSX fork, install a compatible `.vsix` manually or skip that ID.

---

## 3. Global Settings Breakdown (`ide/settings.json`)

[`ide/settings.json`](../ide/settings.json) is valid JSONC containing 29 settings keys across editor behavior, formatting, languages, and tooling:

- **Appearance & Icons:** `"workbench.colorTheme": "Dark Modern"`, `"workbench.iconTheme": "material-icon-theme"`.
- **Editing & Diffs:** `"files.autoSave": "afterDelay"`, `"editor.formatOnSave": true`, `"editor.formatOnPaste": true`, `"editor.defaultFormatter": "esbenp.prettier-vscode"`, `"editor.unicodeHighlight.invisibleCharacters": false`, `"diffEditor.renderSideBySide": false` (inline diffs).
- **Explorer & Git:** `"explorer.confirmDelete": false`, `"explorer.confirmPasteNative": false`, `"git.openRepositoryInParentFolders": "always"`.
- **Web, CSS & Language Overrides:** automatic TS/JS import updates on file move, `"python.languageServer": "Default"`, `"python.analysis.typeCheckingMode": "standard"`, CSS unknown rule/property lint suppression (for Tailwind directives), `[svg]` formatter (`jock.svg`), `[prisma]` formatter (`ajmnz.prisma-import`), `"svg.preview.mode": "img"`, `"docker.extension.dockerEngineAvailabilityPrompt": false`.
- **GitHub Copilot:** enabled globally (`*`, `python`, `typescriptreact`) with `github.copilot.nextEditSuggestions.enabled: true`, disabled for `plaintext`, `markdown`, `scminput`, and `prisma`.

### SDK & Token Placeholders

Three keys are sanitized with placeholders in `ide/settings.json`:

| Setting Key | Placeholder | Expected Local Value |
| :--- | :--- | :--- |
| `sourcery.token` | `${env:SOURCERY_TOKEN}` | Personal Sourcery token |
| `dart.flutterSdkPath` | `${env:FLUTTER_ROOT}` | Local Flutter SDK root (e.g., `~/dev/flutter` or `C:\dev\flutter`) |
| `java.jdt.ls.java.home` | `${env:JAVA_HOME}` | Local JDK or Android Studio JBR directory |

> [!NOTE]
> VS Code user `settings.json` does not expand `${env:...}` inside most extension settings. Always resolve these placeholders in the deployed local file via `-ResolvePaths` / `--resolve-paths`, the `ide-config-adapter` AI skill, or manual editing in your local User folder. Never commit resolved paths or tokens back to git.

---

## 4. Curated 27-Extension Stack

[`ide/extensions.txt`](../ide/extensions.txt) groups all 27 curated extensions by domain:

| Category | Extension IDs |
| :--- | :--- |
| **Mobile & Cross-Platform (Flutter / Dart)** (5) | `dart-code.dart-code`, `dart-code.flutter`, `nash.awesome-flutter-snippets`, `robert-brunhage.flutter-riverpod-snippets`, `jeroen-meijer.pubspec-assist` |
| **Language Support & Debuggers** (6) | `ms-python.python`, `ms-python.debugpy`, `meta.pyrefly`, `golang.go`, `llvm-vs-code-extensions.vscode-clangd`, `shopify.ruby-lsp` |
| **Code Quality, Formatting & Utilities** (5) | `esbenp.prettier-vscode`, `usernamehw.errorlens`, `aaron-bond.better-comments`, `formulahendry.code-runner`, `imgildev.vscode-code-log-plus` |
| **Git & CI/CD** (3) | `mhutchie.git-graph`, `donjayamanne.githistory`, `github.vscode-github-actions` |
| **Containers & DevOps** (2) | `ms-azuretools.vscode-docker`, `ms-azuretools.vscode-containers` |
| **Documentation & Markdown** (3) | `davidanson.vscode-markdownlint`, `shd101wyy.markdown-preview-enhanced`, `mathematic.vscode-pdf` |
| **UI, Preview & Agent Tooling** (3) | `pkief.material-icon-theme`, `ritwickdey.liveserver`, `jlcodes.antigravity-cockpit` |

### Workspace Recommendations Template

Copy [`ide/extensions.json`](../ide/extensions.json) to `<project-root>/.vscode/extensions.json` so contributors opening a repository receive prompts to install the same 27 extensions.

---

## 5. Automated Extension Install & Settings Deployment

Use the scripts in [`scripts/`](../scripts/README.md) rather than copying files manually.

### Extension Installer (`scripts/install-extensions.*`)

```powershell
# Windows: preview missing extensions across all detected IDEs
.\scripts\install-extensions.ps1 -Ide auto -Mode missing -DryRun

# Install missing extensions into Antigravity only
.\scripts\install-extensions.ps1 -Ide antigravity -Mode missing

# Reinstall every extension in a custom list into VS Code with --force
.\scripts\install-extensions.ps1 -Ide vscode -Mode all -ExtensionsFile .\ide\extensions.txt -Force
```

```bash
# macOS / Linux: preview missing extensions across all detected IDEs
./scripts/install-extensions.sh --ide auto --missing --dry-run

# Install missing extensions into Cursor only
./scripts/install-extensions.sh --ide cursor --missing
```

### Settings Deployer (`scripts/deploy-configs.*`)

```powershell
# Windows: preview settings deployment with local SDK/home resolution
.\scripts\deploy-configs.ps1 -Target ide -Ide auto -ResolvePaths -DryRun

# Deploy settings.json (automatically creates settings.json.bak.<YYYYMMDD-HHmmss>)
.\scripts\deploy-configs.ps1 -Target ide -Ide auto -ResolvePaths
```

```bash
# macOS / Linux: preview and deploy settings.json across detected IDEs
./scripts/deploy-configs.sh --target ide --ide auto --resolve-paths --dry-run
./scripts/deploy-configs.sh --target ide --ide auto --resolve-paths
```

Flags supported by `deploy-configs.ps1` / `deploy-configs.sh`:

- `-Ide` / `--ide`: `auto`, `all`, `vscode`, `antigravity`, `cursor`, `windsurf`, `codium`
- `-ResolvePaths` / `--resolve-paths`: auto-detects `flutter`, `java` JDK (`/usr/libexec/java_home` on macOS or `PATH` lookup), and `HOME` to resolve `${HOME}`, `${env:FLUTTER_ROOT}`, `${env:JAVA_HOME}`, and any already-exported `${env:*}` variables in JSON/JSONC templates (skipping `//` comment lines)
- `-DryRun` / `--dry-run`: prints planned backups and writes without modifying disk
- `-NoBackup` / `--no-backup`: overwrites existing targets without creating `*.bak.<timestamp>` files

---

## 6. Non-VS Code Editor Stubs (`ide/stubs/`)

Starter parity configurations live under [`ide/stubs/`](../ide/README.md#non-vs-code-stubs) for teams or machines using JetBrains, Neovim, or Zed:

| Editor | Stub Files | Target Host Path | Parity Included |
| :--- | :--- | :--- | :--- |
| **JetBrains IDEs** (IntelliJ, Android Studio, PyCharm, GoLand, WebStorm) | [`ide/stubs/jetbrains/.ideavimrc`](../ide/stubs/jetbrains/.ideavimrc), [`README.md`](../ide/stubs/jetbrains/README.md) | `~/.ideavimrc` (`%USERPROFILE%\.ideavimrc`) | IdeaVim leader mappings (`<leader>ff`, `<leader>fg`, `<leader>f`, `<leader>ca`, `]d`/`[d`), `.editorconfig` inheritance, Marketplace plugin mapping (Flutter, Dart, Inspection Lens, GitToolBox, Atom Material Icons) |
| **Neovim (`>= 0.10`)** | [`ide/stubs/neovim/init.lua`](../ide/stubs/neovim/init.lua), [`README.md`](../ide/stubs/neovim/README.md) | `~/.config/nvim/init.lua` (`%LOCALAPPDATA%\nvim\init.lua`) | `lazy.nvim` bootstrap, `onedark.nvim` dark theme, `nvim-web-devicons`, `conform.nvim` format-on-save (`prettier`, `ruff_format`/`black`, `dart_format`, `gofmt`), inline `virtual_text` diagnostics, `mason-lspconfig` (`ts_ls`, `pyright`, `gopls`, `clangd`, `ruby_lsp`, `marksman`, `lua_ls`, `dartls`), `telescope.nvim`, `gitsigns.nvim` |
| **Zed** | [`ide/stubs/zed/settings.json`](../ide/stubs/zed/settings.json), [`README.md`](../ide/stubs/zed/README.md) | `~/.config/zed/settings.json` (`%APPDATA%\Zed\settings.json`) | Dark `One Dark` theme, `after_delay` autosave (1000ms), `format_on_save: "on"` with Prettier, inline diagnostics, per-language tab overrides matching `.editorconfig`, `dart language-server` LSP config |
