# Installation & Deployment Scripts

Cross-platform automation for installing curated IDE extensions and deploying sanitized IDE and AI agent configurations on Windows (PowerShell) and macOS/Linux (Bash).

## Contents

- [`install-extensions.ps1`](install-extensions.ps1): Windows PowerShell extension installer for VS Code-family IDEs.
- [`install-extensions.sh`](install-extensions.sh): macOS and Linux Bash extension installer.
- [`deploy-configs.ps1`](deploy-configs.ps1): Windows PowerShell configuration template deployer with timestamped backups and optional path resolution.
- [`deploy-configs.sh`](deploy-configs.sh): macOS and Linux Bash configuration template deployer.

## Supported IDE Mapping

Both extension installers and config deployers target the same five VS Code-family editors:

| IDE Key | Display Name | CLI Binary | Config Folder Name |
| :--- | :--- | :--- | :--- |
| `vscode` | VS Code | `code` | `Code` |
| `antigravity` | Antigravity | `agy` | `Antigravity` |
| `cursor` | Cursor | `cursor` | `Cursor` |
| `windsurf` | Windsurf | `windsurf` | `Windsurf` |
| `codium` | VSCodium | `codium` | `VSCodium` |

When `--ide auto` (Bash) or `-Ide auto` (PowerShell) is used:

- `install-extensions.*` probes `PATH` for each CLI binary and installs extensions into every detected IDE (warning clearly if none is found).
- `deploy-configs.*` detects an IDE if either its CLI binary is on `PATH` or its local IDE config directory already exists.

## Extension Installation

Reads newline-delimited extension IDs from [`../ide/extensions.txt`](../ide/extensions.txt), ignoring blank lines and `#` comments.

### PowerShell Flags (`install-extensions.ps1`)

| Flag | Values | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Ide` | `auto`, `all`, `vscode`, `antigravity`, `cursor`, `windsurf`, `codium` | `auto` | Target IDE(s) |
| `-Mode` | `all`, `missing` | `all` | `missing` queries `--list-extensions` first and installs only absent IDs |
| `-ExtensionsFile` | File path | `<repo>/ide/extensions.txt` | Custom extension list path |
| `-Force` | Switch | Off | Pass `--force` to each install command |
| `-DryRun` | Switch | Off | Print planned commands without installing |

### Bash Flags (`install-extensions.sh`)

| Flag | Values | Default | Description |
| :--- | :--- | :--- | :--- |
| `--ide <target>` | `auto`, `all`, `vscode`, `antigravity`, `cursor`, `windsurf`, `codium` | `auto` | Target IDE(s) |
| `--missing` | Flag | Off | Query `--list-extensions` and skip extensions already installed |
| `--file <path>` | File path | `<repo>/ide/extensions.txt` | Custom extension list path |
| `--force` | Flag | Off | Pass `--force` to each install command |
| `--dry-run` | Flag | Off | Print planned commands without installing |
| `-h`, `--help` | Flag | Off | Display usage text |

### Extension Examples

```powershell
# Preview missing extension installs across all detected IDEs
.\scripts\install-extensions.ps1 -Ide auto -Mode missing -DryRun

# Install missing extensions only into VS Code
.\scripts\install-extensions.ps1 -Ide vscode -Mode missing

# Reinstall all curated extensions into Antigravity with --force
.\scripts\install-extensions.ps1 -Ide antigravity -Mode all -Force
```

```bash
# Make Bash scripts executable once on macOS or Linux
chmod +x scripts/*.sh

# Preview missing extensions across all detected IDEs
./scripts/install-extensions.sh --ide auto --missing --dry-run

# Install missing extensions into Cursor
./scripts/install-extensions.sh --ide cursor --missing
```

## Configuration Deployment

Copies repository templates to each IDE and AI agent location while keeping secrets out of git.

### PowerShell Flags (`deploy-configs.ps1`)

| Flag | Values | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Target` | `all`, `ide`, `antigravity`, `opencode`, `commandcode`, `mcp`, `workspace` | `all` | Target group(s) to deploy (accepts comma-separated list) |
| `-Ide` | `auto`, `all`, `vscode`, `antigravity`, `cursor`, `windsurf`, `codium` | `auto` | Target IDE(s) when deploying `ide` |
| `-WorkspacePath` | Directory path | `.` | Project root for `workspace` (`<WorkspacePath>/.agents/`) |
| `-ResolvePaths` | Switch | Off | Auto-detect `flutter`, `java` JDK, and home directory to resolve `${HOME}`, `${env:FLUTTER_ROOT}`, `${env:JAVA_HOME}`, and set `${env:*}` vars |
| `-DryRun` | Switch | Off | Preview backups and file writes without writing to disk |
| `-NoBackup` | Switch | Off | Overwrite target files directly without `*.bak.<timestamp>` copies |

### Bash Flags (`deploy-configs.sh`)

| Flag | Values | Default | Description |
| :--- | :--- | :--- | :--- |
| `--target <name>` | `all`, `ide`, `antigravity`, `opencode`, `commandcode`, `mcp`, `workspace` | `all` | Target group(s) to deploy (comma-separated allowed) |
| `--ide <target>` | `auto`, `all`, `vscode`, `antigravity`, `cursor`, `windsurf`, `codium` | `auto` | Target IDE(s) when deploying `ide` |
| `--workspace <path>` | Directory path | `.` | Project root for `workspace` (`<workspace>/.agents/`) |
| `--resolve-paths` | Flag | Off | Auto-detect `flutter`, `java` JDK, and `HOME`; substitute `${HOME}`, `${env:FLUTTER_ROOT}`, `${env:JAVA_HOME}`, and set `${env:*}` vars |
| `--dry-run` | Flag | Off | Preview backups and file writes without writing to disk |
| `--no-backup` | Flag | Off | Overwrite target files directly without `*.bak.<timestamp>` copies |
| `-h`, `--help` | Flag | Off | Display usage text |

### Target Path Mapping Across OS

| Target | Source in Repo | Windows Destination | macOS Destination | Linux Destination |
| :--- | :--- | :--- | :--- | :--- |
| `ide` | `ide/settings.json` | `%APPDATA%\<IDE>\User\settings.json` | `~/Library/Application Support/<IDE>/User/settings.json` | `~/.config/<IDE>/User/settings.json` |
| `antigravity` | `AGENTS.md` | `~/.gemini/GEMINI.md` | `~/.gemini/GEMINI.md` | `~/.gemini/GEMINI.md` |
| `antigravity` | `agent/antigravity/skills.json` | `~/.gemini/config/skills.json` | `~/.gemini/config/skills.json` | `~/.gemini/config/skills.json` |
| `antigravity` | `agent/antigravity/config.template.json` | `~/.gemini/config/config.template.json` | `~/.gemini/config/config.template.json` | `~/.gemini/config/config.template.json` |
| `mcp` | `agent/mcp/mcp_config.json` | `~/.gemini/config/mcp_config.json` | `~/.gemini/config/mcp_config.json` | `~/.gemini/config/mcp_config.json` |
| `opencode` | `agent/opencode/*` (excluding `README.md`) | `~/.config/opencode/` | `~/.config/opencode/` | `~/.config/opencode/` |
| `commandcode` | `agent/commandcode/*` (excluding `README.md`) | `~/.opencode/` | `~/.opencode/` | `~/.opencode/` |
| `workspace` | `agent/workspace/*` (excluding `README.md`) | `<WorkspacePath>\.agents\` | `<WorkspacePath>/.agents/` | `<WorkspacePath>/.agents/` |

Notes on `ide` folder names: replace `<IDE>` with `Code`, `Antigravity`, `Cursor`, `Windsurf`, or `VSCodium`. On Linux, `$XDG_CONFIG_HOME` is honored when set.

Notes on `workspace` when running `all`: if `--target all` / `-Target all` is invoked from inside this configuration repository with the default `.` workspace path, the `workspace` target is skipped automatically to avoid creating `.agents/` inside the template repository itself. Pass `-Target workspace` / `--target workspace` or specify `-WorkspacePath <project-dir>` / `--workspace <project-dir>` to deploy `.agents/` into a project.

### Deployment Examples

```powershell
# Dry-run full deployment with local SDK and home path resolution
.\scripts\deploy-configs.ps1 -Target all -Ide auto -ResolvePaths -DryRun

# Deploy IDE settings and MCP config with backups enabled
.\scripts\deploy-configs.ps1 -Target ide,mcp -Ide vscode -ResolvePaths

# Deploy .agents/ workspace rules and workflows into a target project
.\scripts\deploy-configs.ps1 -Target workspace -WorkspacePath D:\Projects\my-app
```

```bash
# Dry-run full deployment on macOS or Linux
./scripts/deploy-configs.sh --target all --ide auto --resolve-paths --dry-run

# Deploy OpenCode and Antigravity configs
./scripts/deploy-configs.sh --target antigravity,opencode --resolve-paths

# Deploy .agents/ template into a project directory
./scripts/deploy-configs.sh --target workspace --workspace ~/projects/my-app
```

## Safety, Backups & Placeholder Behavior

1. **Always preview with Dry-Run first**: Run with `-DryRun` (PowerShell) or `--dry-run` (Bash) to verify every source file, backup target, and destination path before writing to disk.
2. **Automatic Timestamped Backups**: Whenever a destination file already exists, `deploy-configs` copies it to `<target-file>.bak.<YYYYMMDD-HHMMSS>` before writing the new file, unless `-NoBackup` / `--no-backup` is explicitly passed.
3. **Antigravity `config.json` Protection**: Live `~/.gemini/config/config.json` stores machine-specific state and plugin settings and is never overwritten automatically. The script deploys `agent/antigravity/config.template.json` alongside it and prints manual merge guidance.
4. **Placeholder & Secret Safety (`-ResolvePaths` / `--resolve-paths`)**:
   - Without `-ResolvePaths` / `--resolve-paths`, templates are copied verbatim.
   - When enabled, `${HOME}`, `${env:FLUTTER_ROOT}`, and `${env:JAVA_HOME}` are substituted in JSON/JSONC templates using your environment or auto-detected `flutter` and `java` binaries, skipping single-line `//` comments.
   - Secret placeholders (`${env:SOURCERY_TOKEN}`, `${env:CONTEXT7_API_KEY}`, `${env:STITCH_API_KEY}`, `${env:COMMANDCODE_API_KEY}`) remain untouched unless the corresponding environment variable is already defined in your shell, and resolved values are never printed to terminal output.
   - Single-brace `{env:GITHUB_TOKEN}` placeholders in OpenCode configs are preserved for native runtime expansion by OpenCode.
