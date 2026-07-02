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

**Host (WSL / Linux / macOS):** Neovim 0.11+, `git`, `curl`, `ripgrep`, `fd`,
  `python3`, `node`/`npm`, Docker, and a Nerd Font for icons.

**Devcontainer:** Toolchain (clangd, cmake, gcc, ninja, …) – defined in your
  project's `.devcontainer/devcontainer.json` / Dockerfile.

  nvim on the host connects remotely to the devcontainer for LSP, builds,
  and debugging. The host itself does not need the toolchain.

## One-command install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xce3/nvim-config/main/install.sh")'
```

The installer detects the package manager, installs host packages (nvim, git,
ripgrep, fd, node, python, gh, lazygit), backs up an existing `~/.config/nvim`
when needed, clones this repo, and runs Lazy plugin sync.

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

This config supports a devcontainer workflow through the shell launcher. Run
`nvim .` in a project with `.devcontainer/devcontainer.json`; the wrapper asks
whether to open local host nvim or attach to a containerized nvim server.

The legacy in-editor `:Devcontainer*` commands are intentionally not included.
Container lifecycle and attach logic lives in `bin/nvim` and `bin/nvim-dev`.

`<leader>hh` opens the Workspace Hub for recent local projects.

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
