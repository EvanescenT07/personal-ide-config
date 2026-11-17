# Neovim Parity Stub

Minimal Neovim (`>= 0.10`) configuration mapping the global VS Code-family workflow (Prettier format-on-save, inline diagnostics, LSP coverage, Telescope search, and Gitsigns).

## Target Paths

- **macOS / Linux:** `~/.config/nvim/init.lua`
- **Windows:** `%LOCALAPPDATA%\nvim\init.lua`

## Prerequisites

- `neovim >= 0.10`
- `git` (for `lazy.nvim` bootstrap)
- `ripgrep` (`rg`) for `telescope.nvim` live grep
- `prettier` on `PATH` (or local `node_modules/.bin/prettier`) for `conform.nvim`
- Language toolchains on `PATH`: `node`, `python`, `go`, `dart` (for `dartls`), `clangd`

## Parity Mapping

| VS Code Feature / Extension | Neovim Equivalent in `init.lua` |
| :--- | :--- |
| `workbench.colorTheme: "Dark Modern"` | `navarasu/onedark.nvim` (`dark` style) |
| `pkief.material-icon-theme` | `nvim-tree/nvim-web-devicons` |
| `esbenp.prettier-vscode` + `formatOnSave` | `stevearc/conform.nvim` with `format_on_save` |
| `usernamehw.errorlens` | `vim.diagnostic.config({ virtual_text = true })` |
| `ms-python.python`, `golang.go`, `dart-code.dart-code`, `vscode-clangd`, `shopify.ruby-lsp` | `mason-lspconfig.nvim` + `nvim-lspconfig` (`ts_ls`, `pyright`, `gopls`, `clangd`, `ruby_lsp`, `marksman`, `lua_ls`, `dartls`) |
| `mhutchie.git-graph` / Git gutter | `lewis6991/gitsigns.nvim` |
| Quick Open / Find in Files | `nvim-telescope/telescope.nvim` (`<leader>ff`, `<leader>fg`, `<leader>fb`) |
