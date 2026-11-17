# Agent Self-Adaptation Playbook

This repository is designed to be handed directly to any AI coding agent (`Antigravity`, `Claude Code`, `OpenCode`, `CommandCode`, `Cursor`, `Codex`) so the agent inspects your workstation and adapts sanitized templates safely.

---

## 1. How the Bootstrap Protocol Works

1. Most AI agents automatically load [`AGENTS.md`](../AGENTS.md) when opened in the repository root (and Antigravity users load it via [`agent/antigravity/GEMINI.md`](../agent/antigravity/GEMINI.md) or `~/.gemini/GEMINI.md`).
2. **Section 10 (`Agent Bootstrap & Local Config Adaptation`)** in `AGENTS.md` instructs the agent to read [`agent/skills/ide-config-adapter/SKILL.md`](../agent/skills/ide-config-adapter/SKILL.md) completely before touching any local IDE or agent path.
3. The agent runs read-only discovery first, proposes the exact target mappings and backups, confirms before mutating host files, and leaves tracked repository files completely clean.

---

## 2. Five-Step Adaptation Workflow (`ide-config-adapter`)

Every step below mirrors [`agent/skills/ide-config-adapter/SKILL.md`](../agent/skills/ide-config-adapter/SKILL.md):

### Step 1: Detect Host OS & Home Paths

Read-only inspection of the operating system and user directories:

- **Windows (PowerShell):** `$env:OS`, `$env:USERPROFILE`, `$env:APPDATA`, `$env:LOCALAPPDATA`.
- **macOS / Linux (Bash/Zsh):** `uname -s` (`Darwin` or `Linux`), `$HOME`, `${XDG_CONFIG_HOME:-$HOME/.config}`.
- Paths written into cross-platform JSON files (such as `skills.json`) normalize to forward slashes.

### Step 2: Detect Installed IDEs & Target Paths

The agent checks `PATH` and standard OS application data folders for:

- **VS Code-family IDEs:** `code` (`Code`), `agy` (`Antigravity`), `cursor` (`Cursor`), `windsurf` (`Windsurf`), `codium` (`VSCodium`). Runs `<cli> --list-extensions` to compute missing items against [`ide/extensions.txt`](../ide/extensions.txt).
- **Non-VS Code editors (optional stubs):** `idea`/`studio`/`pycharm`/`goland` (`~/.ideavimrc`), `nvim` (`~/.config/nvim/init.lua` or `%LOCALAPPDATA%\nvim\init.lua`), `zed` (`~/.config/zed/settings.json` or `%APPDATA%\Zed\settings.json`).

### Step 3: Probe Local SDKs, Runtimes & Env Vars

Read-only checks resolve local paths without modifying PATH or shell profiles:

- `flutter` (`$FLUTTER_ROOT` or binary parent stripping `\bin\flutter.bat` / `/bin/flutter`) -> resolves `dart.flutterSdkPath`
- `java` (`$JAVA_HOME`, `/usr/libexec/java_home` on macOS, Android Studio `jbr`, or JDK root containing `release` / `javac`) -> resolves `java.jdt.ls.java.home`
- `python` / `python3` and `uv` (required for `graphify` MCP)
- `node` and `npx` (required for `context7`, `playwright`, `rea`, and `github` MCP servers)
- `dart` (required for `dart-mcp-server`) and `go`
- **Secret Env Var Presence Only:** Checks whether `SOURCERY_TOKEN`, `CONTEXT7_API_KEY`, `STITCH_API_KEY`, `COMMANDCODE_API_KEY`, and `GITHUB_TOKEN` are set, reporting missing names without ever printing secret values.

### Step 4: Adapt & Merge Safely

Before modifying any external config file:

1. **Timestamped Backup:** Copy existing targets to `<file>.bak.<YYYYMMDD-HHmmss>`.
2. **JSONC-Aware Merging:** Parse `settings.json` with a JSONC-capable parser (`jsonc-parser` or comment-tolerant script) to merge baseline keys from `ide/settings.json` while preserving user customizations and keeping unresolved SDKs safe.
3. **Never Overwrite Live `~/.gemini/config/config.json`:** Merge `plugins` and `globalPermissionGrants` from `agent/antigravity/config.template.json` while preserving `installedFrom`, `remoteControlHostname`, and `projects`.
4. **Cross-Platform MCP Adjustments:** On Windows, switch bare `"npx"` commands to `"npx.cmd"` or `["cmd.exe", "/d", "/c", "npx", ...]` if GUI MCP spawns fail.
5. **Prefer Tested Scripts:** Use `scripts/install-extensions.*` and `scripts/deploy-configs.*` with `-DryRun` / `--dry-run` first, then `-ResolvePaths` / `--resolve-paths` after confirmation.

### Step 5: Verify & Report

After applying approved changes, the agent must:

1. Validate every modified `.json` / `.jsonc` target parses cleanly.
2. Run `git status` and `git diff` inside this repository to confirm zero personal paths or secrets leaked into tracked files.
3. Report modified targets, backup paths, resolved SDK roots, unset environment variables, and manual Marketplace plugins (`antislop`, `coderabbit`, `firebase`, `android-cli-plugin`, `google-antigravity-sdk`) or lockfile skills (`agent/skills/.skill-lock.json`).

---

## 3. Ready-to-Use Prompts

### Full Workstation Setup (Interactive)

```text
Follow AGENTS.md Section 10 and agent/skills/ide-config-adapter/SKILL.md.
1. Inspect my OS, installed IDEs, existing agent configs, and SDK paths (flutter, java, python, uv, node, dart, go) in read-only mode.
2. Check which required env vars (SOURCERY_TOKEN, CONTEXT7_API_KEY, STITCH_API_KEY, COMMANDCODE_API_KEY, GITHUB_TOKEN) are present without printing values.
3. Present a dry-run adaptation plan with exact target paths and backups before modifying anything.
```

### Targeted Single-Tool Adaptation

```text
Read agent/skills/ide-config-adapter/SKILL.md. Adapt only my Antigravity IDE settings, ~/.gemini/GEMINI.md, and ~/.gemini/config/mcp_config.json. Back up existing files first, preserve live ~/.gemini/config/config.json state, and verify JSON syntax after merging.
```

### Bootstrapping Another Project Repository

```text
Using AGENTS.md and agent/workspace/README.md, deploy .agents/ (skills.json, rules/graphify.md, workflows/graphify.md), .editorconfig, and .vscode/extensions.json into <path-to-target-repo> with ${HOME} resolved cleanly in the target project copy only.
```
