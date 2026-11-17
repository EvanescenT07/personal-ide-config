# JetBrains IDE Parity Guide

Mapping from the global VS Code-family profile (`ide/settings.json` and `ide/extensions.txt`) to JetBrains IDEs (IntelliJ IDEA, Android Studio, PyCharm, GoLand, WebStorm).

## Deploying `.ideavimrc`

Copy [`.ideavimrc`](.ideavimrc) to your home directory after installing the **IdeaVim** plugin:

- **Windows:** `copy ide\stubs\jetbrains\.ideavimrc %USERPROFILE%\.ideavimrc`
- **macOS / Linux:** `cp ide/stubs/jetbrains/.ideavimrc ~/.ideavimrc`

## Built-In Settings Parity

JetBrains IDEs automatically read the root `.editorconfig` file when **Settings -> Editor -> Code Style -> Enable EditorConfig support** is enabled (default on).

| VS Code Setting | JetBrains Equivalent |
| :--- | :--- |
| `workbench.colorTheme: "Dark Modern"` | **Appearance & Behavior -> Appearance -> Theme**: Dark |
| `files.autoSave: "afterDelay"` | Enabled natively (configure idle delay under **System Settings -> Autosave**) |
| `editor.formatOnSave: true` | **Tools -> Actions on Save**: enable *Reformat code* and *Optimize imports* |
| `editor.defaultFormatter: "esbenp.prettier-vscode"` | **Languages & Frameworks -> JavaScript -> Prettier**: Automatic Prettier configuration + *Run on save* |
| `diffEditor.renderSideBySide: false` | Diff toolbar gear icon -> switch viewer from *Side-by-side* to *Unified viewer* |
| `dart.flutterSdkPath` / `java.jdt.ls.java.home` | **Languages & Frameworks -> Flutter / Dart** and **Build, Execution, Deployment -> Project SDK** |

## Plugin Mapping

| VS Code Extension | JetBrains Plugin / Built-In Feature |
| :--- | :--- |
| `dart-code.flutter`, `dart-code.dart-code` | **Flutter** and **Dart** (Marketplace plugins; core for Android Studio / IntelliJ) |
| `ms-python.python`, `ms-python.debugpy` | **Python** (built into PyCharm; plugin in IntelliJ Ultimate) |
| `golang.go` | **Go** (built into GoLand; plugin in IntelliJ Ultimate) |
| `esbenp.prettier-vscode` | **Prettier** (bundled in WebStorm / IntelliJ Ultimate) |
| `usernamehw.errorlens` | **Inspection Lens** (Marketplace plugin for inline diagnostic messages) |
| `mhutchie.git-graph`, `donjayamanne.githistory` | Built-in **Git** tool window (Log graph + File History) + **GitToolBox** plugin |
| `github.vscode-github-actions` | Built-in **GitHub** + **GitHub Actions** support |
| `ms-azuretools.vscode-docker` | **Docker** (bundled / Marketplace plugin) |
| `pkief.material-icon-theme` | **Atom Material Icons** (Marketplace plugin) |
| `davidanson.vscode-markdownlint` | Built-in **Markdown** plugin + bundled inspections |
| `aaron-bond.better-comments` | Built-in `TODO` / custom comment patterns under **Editor -> TODO** |
