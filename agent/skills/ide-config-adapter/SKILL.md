---
name: ide-config-adapter
description: Inspects host OS, installed IDEs, AI agent runtimes, and SDK paths, then safely adapts and merges ide/ and agent/ templates from this repository into local machine paths without clobbering existing settings or leaking secrets.
---

# IDE & Agent Config Adapter

Use this skill whenever the user provides this repository to set up a new workstation, synchronize configs across editors/agents, or adapt sanitized templates (`ide/`, `agent/`, `.editorconfig`, `AGENTS.md`) to their local machine.

## Non-Negotiable Safety Rules

1. **Read-Only Discovery First:** Inspect the host OS, binaries, SDKs, and existing target files before proposing or writing any change.
2. **Never Leak Secrets or Personal Paths Into Git:** Keep all repository files sanitized with `${env:...}`, `{env:...}`, and `${HOME}` placeholders. Write resolved local SDK paths or user home paths only into the host's external config targets, never into tracked repository files.
3. **Never Clobber Live Configs:** Always create a timestamped backup (`<target>.bak.<YYYYMMDD-HHmmss>`) before modifying an existing file.
4. **Merge Rather Than Blindly Overwrite:** Preserve existing user keys, themes, keybindings, project grants, and auth/runtime state in `settings.json` and `~/.gemini/config/config.json`.
5. **Confirm Before Mutating Host State:** Present the exact list of source-to-target mappings, unresolved secrets, and backup paths, and confirm with the user before writing outside the repository (or advise running `scripts/deploy-configs.ps1` / `scripts/deploy-configs.sh`).

---

## Step 1: Detect Host OS & Home Paths

Run read-only environment checks appropriate for the current shell:

- **Windows (PowerShell):**
  - `$env:OS`, `$env:USERPROFILE`, `$env:APPDATA`, `$env:LOCALAPPDATA`
- **macOS / Linux (Bash/Zsh):**
  - `uname -s` (`Darwin` vs `Linux`), `$HOME`, `${XDG_CONFIG_HOME:-$HOME/.config}`

Normalize forward slashes when writing paths into JSON files consumed cross-platform (such as `skills.json`).

---

## Step 2: Detect Installed IDEs & Target Paths

Check which editors are installed on `PATH` or in standard OS locations:

| Editor | CLI Binary | Windows Target (`settings.json`) | macOS Target (`settings.json`) | Linux Target (`settings.json`) |
| :--- | :--- | :--- | :--- | :--- |
| VS Code | `code` | `%APPDATA%\Code\User\settings.json` | `~/Library/Application Support/Code/User/settings.json` | `~/.config/Code/User/settings.json` |
| Antigravity | `agy` | `%APPDATA%\Antigravity\User\settings.json` | `~/Library/Application Support/Antigravity/User/settings.json` | `~/.config/Antigravity/User/settings.json` |
| Cursor | `cursor` | `%APPDATA%\Cursor\User\settings.json` | `~/Library/Application Support/Cursor/User/settings.json` | `~/.config/Cursor/User/settings.json` |
| Windsurf | `windsurf` | `%APPDATA%\Windsurf\User\settings.json` | `~/Library/Application Support/Windsurf/User/settings.json` | `~/.config/Windsurf/User/settings.json` |
| VSCodium | `codium` | `%APPDATA%\VSCodium\User\settings.json` | `~/Library/Application Support/VSCodium/User/settings.json` | `~/.config/VSCodium/User/settings.json` |
| JetBrains IDEs | `idea`, `studio`, `pycharm`, `goland` | `~/.ideavimrc` | `~/.ideavimrc` | `~/.ideavimrc` |
| Neovim | `nvim` | `%LOCALAPPDATA%\nvim\init.lua` | `~/.config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| Zed | `zed` | `%APPDATA%\Zed\settings.json` | `~/.config/zed/settings.json` | `~/.config/zed/settings.json` |

For VS Code-family editors, also detect installed extensions via `<cli> --list-extensions` to compute missing items against `ide/extensions.txt`.

---

## Step 3: Detect Local SDKs, Runtimes & Env Vars

Probe installed tools (read-only) to resolve SDK placeholders safely:

1. **Flutter (`${env:FLUTTER_ROOT}`):**
   - Check `$env:FLUTTER_ROOT` / `$FLUTTER_ROOT`, then `Get-Command flutter` (Windows) or `command -v flutter` (POSIX).
   - Strip trailing `/bin/flutter` or `\bin\flutter.bat` to obtain the SDK root directory.
2. **Java / JDK (`${env:JAVA_HOME}`):**
   - Check `$env:JAVA_HOME` / `$JAVA_HOME`, then `java` on `PATH` or Android Studio `jbr` / SDKMAN / Homebrew OpenJDK paths.
3. **Python & `uv`:**
   - Check `python` / `python3` and `uv` (required for `graphify` MCP server).
4. **Node.js & `npx`:**
   - Check `node` and `npx` (required for `context7`, `playwright`, `rea`, and `github` MCP servers).
5. **Dart & Go:**
   - Check `dart` (required for `dart-mcp-server`) and `go`.
6. **Secret Env Vars (Check Presence Only, Never Print Values):**
   - Verify whether `SOURCERY_TOKEN`, `CONTEXT7_API_KEY`, `STITCH_API_KEY`, `COMMANDCODE_API_KEY`, and `GITHUB_TOKEN` are defined in the shell environment. Report missing variables by name only.

---

## Step 4: Adapt & Merge Templates Safely

Apply only the targets relevant to tools detected on the user's machine:

### 4.1 VS Code-Family Settings & Extensions

- **Backup first:** Copy existing `User/settings.json` to `User/settings.json.bak.<timestamp>`.
- **Parse JSONC safely:** Use a JSONC-aware parser (such as Node `jsonc-parser` or Python with comment stripping) so existing user keys and comments are respected.
- **Merge strategy:**
  - Apply baseline keys from `ide/settings.json`.
  - Resolve `"dart.flutterSdkPath"` from detected `FLUTTER_ROOT` and `"java.jdt.ls.java.home"` from detected `JAVA_HOME`. Omit or preserve existing local values if an SDK is not installed on the machine.
  - Keep `"sourcery.token"` as existing local value if already set; otherwise fill from `$env:SOURCERY_TOKEN` if present or leave `"${env:SOURCERY_TOKEN}"` and warn the user.
- **Extensions:** Run `scripts/install-extensions.ps1 -Ide auto -Mode missing` (Windows) or `scripts/install-extensions.sh --ide auto --missing` (macOS/Linux).
- **Non-VS Code IDEs:** Only if `idea`/`nvim`/`zed` are detected and requested, merge/deploy `ide/stubs/jetbrains/.ideavimrc`, `ide/stubs/neovim/init.lua`, or `ide/stubs/zed/settings.json` after reading the corresponding `ide/stubs/*/README.md`.

### 4.2 AI Agent Configs

1. **Antigravity (`~/.gemini/`):**
   - Copy root `AGENTS.md` to `~/.gemini/GEMINI.md` (backing up existing `GEMINI.md` first).
   - Copy `agent/antigravity/skills.json` to `~/.gemini/config/skills.json`, replacing `${HOME}` with the user's real home path (using forward slashes).
   - **Never blindly overwrite `~/.gemini/config/config.json`.** Instead, inspect existing `config.json` (if present), merge missing `plugins` keys and safe `globalPermissionGrants` from `agent/antigravity/config.template.json`, and preserve `installedFrom`, `remoteControlHostname`, and project entries.
2. **MCP Config (`~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity/mcp_config.json`):**
   - Start from `agent/mcp/mcp_config.json` (or `agent/mcp/mcp_config_http.json` if Node/uv are absent).
   - Remove servers whose local runtime is missing only if the user asks, or note missing prerequisites (`uv`, `dart`, `flow-auto-mcp`).
   - On Windows, if the host client cannot spawn plain `"npx"`, adapt `context7` / `playwright` to `"npx.cmd"` and `rea` to `"command": "cmd.exe", "args": ["/d", "/c", "npx", "-y", "rea-agents@6.8.0", "mcp"]`.
   - If the client does not expand `${env:CONTEXT7_API_KEY}` or `${env:STITCH_API_KEY}`, substitute from shell env in the local target file only (never in this repo).
3. **OpenCode (`~/.config/opencode/`):**
   - Deploy `agent/opencode/opencode.jsonc`, `rules.md`, and `package.json`.
   - Adapt `mcp.rea.command` to `["cmd.exe", "/d", "/c", "npx", "-y", "rea-agents@6.8.0", "mcp"]` on Windows if direct `npx` fails.
   - Remind user to export `GITHUB_TOKEN` and run `npm install` in `~/.config/opencode/` if plugin resolution is needed.
4. **CommandCode (`~/.opencode/`):**
   - Deploy `agent/commandcode/opencode.jsonc` and `package.json`.
   - Resolve `"~/.opencode/skills"` in `skills.paths` to the absolute path if the client does not expand `~`.
   - Remind user to export `COMMANDCODE_API_KEY`.
5. **Project Workspace Rules (`<target-project>/.agents/`):**
   - When adapting a specific project repo, deploy `agent/workspace/` (`skills.json`, `rules/graphify.md`, `workflows/graphify.md`) into `<target-project>/.agents/`, resolving `${HOME}` in `skills.json`.
   - Deploy `.editorconfig` and `ide/extensions.json` (to `.vscode/extensions.json`) into `<target-project>` if requested.

---

## Step 5: Verify & Report

After applying changes (or executing `scripts/deploy-configs.*`):

1. Validate every modified `.json` / `.jsonc` target parses cleanly without syntax errors.
2. Verify no tracked file in this repository was dirtied with personal paths or tokens (`git status`, `git diff`).
3. Report to the user:
   - Exact target files created or merged
   - Timestamped backup paths created
   - Resolved SDK roots (`flutter`, `java`)
   - Unresolved environment variables or plugins the user must activate manually (`antislop`, `coderabbit`, `firebase`, `android-cli-plugin`, `google-antigravity-sdk`)
   - Missing skills from `agent/skills/.skill-lock.json` that can be restored via `npx skills`.
