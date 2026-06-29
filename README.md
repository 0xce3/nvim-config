# Neovim config

Personal Neovim configuration for container-friendly C/C++, Python, Git, VS Code
task/launch workflows, and AI-assisted editing. Built on `lazy.nvim`, Telescope,
LSP (`clangd`, `pyright`, `ruff`), and a Gruvbox Soft Dark theme.

The leader key is Space.

## Restore

```sh
git clone https://github.com/0xce3/nvim-config.git ~/.config/nvim
nvim
```

`lazy.nvim` bootstraps itself on first start and installs the configured plugins.

## Requirements

- Neovim 0.11 or newer
- `git`, `curl`, `ripgrep`, `fd`
- `clangd` and `clang-format` for C/C++
- `node`/`npm` and Python tooling for language servers
- GitHub CLI (`gh`) for Octo
- A Nerd Font on the host terminal for file/status icons

## One-command install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xce3/nvim-config/main/install.sh)"
```

The installer detects common package managers, installs helper tools, backs up an
existing `~/.config/nvim` when needed, clones this repo, installs Python/Node
language tooling, and runs Lazy plugin sync.

For local testing:

```sh
./install.sh --dry-run
./install.sh --skip-packages
```

## Core Plugins

| Category | Plugin | Purpose |
|----------|--------|---------|
| Theme/UI | `ellisonleao/gruvbox.nvim`, `lualine.nvim`, `bufferline.nvim`, `which-key.nvim` | Colors, statusline, buffers, key hints |
| Explorer | `nvim-telescope/telescope-file-browser.nvim` | File browser on `<leader>e` |
| Find | `fzf-lua`, `telescope.nvim` | Fast project search and shared picker backend |
| LSP | `nvim-lspconfig`, `mason.nvim`, `mason-tool-installer.nvim` | Language servers and tooling |
| Completion | `nvim-cmp`, `LuaSnip` | Completion and snippets |
| Syntax | `nvim-treesitter/nvim-treesitter`, `rainbow-delimiters.nvim` | Parsing, highlighting, delimiters |
| Git | `vim-fugitive`, `gitsigns.nvim`, `octo.nvim`, `snacks.nvim` | Git status, hunks, GitHub PRs, lazygit |
| Debug | `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text` | DAP debugging |
| Tasks | `vs-tasks.nvim` | Run `.vscode/tasks.json` and launch configs |
| AI | `opencode.nvim` | Optional opencode integration |

Exact pinned versions live in `lazy-lock.json`.

## Devcontainer (Remote Workflow)

This config supports a full VS Code-like devcontainer workflow. nvim runs on the
host (WSL) with your full config/themes; the container provides toolchain + workspace.

| Key | Command | Action |
|-----|---------|--------|
| `<leader>Dr` | `:DevcontainerReopen` | Detect `.devcontainer.json` → build/start → route LSP |
| `<leader>Du` | `:DevcontainerUp` | Build and start devcontainer |
| `<leader>Dc` | `:DevcontainerConnect` | List running containers → attach |
| `<leader>DR` | `:DevcontainerRebuild` | Rebuild container from scratch |
| `<leader>Dd` | `:DevcontainerStop` | Stop container |
| `<leader>Ds` | `:DevcontainerShell` | Open shell in container |
| `<leader>Dh` | `:DevcontainerHub` | Open workspace hub |
| `<leader>hh` | – | Workspace hub (projects + containers) |

When nvim starts without arguments, the Workspace Hub opens automatically
showing recent projects, devcontainer projects, and running containers.

## Keybindings

| Key | Action |
|-----|--------|
| `<leader>w` | Save file |
| `<leader>e` | Open workspace-scoped Telescope file browser |
| `<leader>E` | Open unrestricted Telescope file browser |
| `<leader>x` / `<leader>X` | Close buffer / force close buffer; also closes terminal buffers |
| `<Tab>` / `<S-Tab>` | Next / previous buffer |
| `<leader>1` ... `<leader>9` | Jump to buffer |
| `<leader>gg` | Fugitive Git status |
| `<leader>gl` | Lazygit |
| `<leader>gn` / `<leader>gp` | Next / previous Git hunk |
| `<leader>fc` | Pick active `compile_commands.json` for clangd |
| `<leader>tr` | Run VS Code task |
| `<leader>tl` | Run VS Code launch config |
| `<leader>tj` / `<F12>` | Toggle reusable terminal buffer |
| `<leader>tq` | Leave reusable terminal buffer |
| `<F5>` | Continue debug session or run first launch config |
| `<F9>` | Toggle breakpoint |
| `<F10>` / `<F11>` / `<S-F11>` | Step over / into / out |
| `<leader>du` | Toggle debug UI |
| `<leader>dr` | Open debug REPL |

## VS Code Tasks And Launches

Tasks are read from `.vscode/tasks.json` through `vs-tasks.nvim`. Task commands
run in a single reusable terminal buffer shown like any other buffer.

Terminal buffers can be closed with `<leader>x`, `q`, or `:q` from normal mode.

Debug launches are read from `.vscode/launch.json` where possible and executed
through `nvim-dap`. `:DebugLaunch` runs the first launch config by default, or a
named config when provided.

## clangd Build Selection

`<leader>fc` lists discovered `compile_commands.json` files under the current
project. Selecting one stores the chosen build directory in Neovim's state dir
and restarts clangd with `--compile-commands-dir`. No generated project files or
symlinks are written to the source tree.

## Structure

```text
init.lua                         bootstrap
lua/config/options.lua           options and clipboard/folding behavior
lua/config/keymaps.lua           global keymaps and formatting helpers
lua/config/lazy.lua              lazy.nvim bootstrap
lua/config/terminal.lua          reusable terminal buffer
lua/config/vscode_debug.lua      generic VS Code launch/task debug helpers
lua/config/container_detect.lua  Docker/devcontainer runtime detection
lua/config/devcontainer.lua      devcontainer lifecycle (reopen/connect/stop)
lua/config/workspace_hub.lua     telescope workspace hub picker
lua/plugins/init.lua             plugin specs and per-plugin config
lua/plugins/compile_commands.lua clangd compile_commands picker
```
