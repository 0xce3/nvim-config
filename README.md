# Neovim config

Personal Neovim configuration for a devcontainer-based development workflow.

## Restore in a fresh container

```sh
git clone https://github.com/0xce3/nvim-config.git ~/.config/nvim
nvim
```

`lazy.nvim` bootstraps itself on first start and installs the configured plugins.

## Requirements

- Neovim 0.11 or newer
- `ripgrep` for project-wide text search through Telescope (`<leader>fg`)
- `fd` for fast file discovery through Telescope (`<leader>ff`)

## One-command install

On a fresh Linux or macOS host:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xce3/nvim-config/main/install.sh)"
```

The installer detects `apt`, `dnf`, `pacman`, `apk`, or `brew`, installs Neovim and helper tools, verifies Neovim 0.11 or newer, backs up an existing `~/.config/nvim` if needed, clones this config, installs GitHub CLI support, `pyright`, and `ruff`, then runs Lazy plugin sync.

For local testing:

```sh
./install.sh --dry-run
./install.sh --skip-packages
```

## Required font

Icons in neo-tree and the status line require a **Nerd Font** installed on the **Windows host** (not inside the container).

1. Download **JetBrainsMono Nerd Font** from https://www.nerdfonts.com/font-downloads
2. Extract the zip and install `JetBrainsMonoNerdFontMono-Regular.ttf` (right-click → Install for all users)
3. Open Windows Terminal settings → select your WSL profile → Appearance → set font to `JetBrainsMono Nerd Font Mono`
4. Restart Windows Terminal

Without this font, icons appear as boxes or question marks.

## Windows and WSL launcher

For Windows Terminal, WSL, Docker, and devcontainer session launching, use ShellHopper:

```powershell
irm https://raw.githubusercontent.com/0xce3/shell-hopper/main/install.ps1 | iex
```

Repository: https://github.com/0xce3/shell-hopper

## Current focus

- GitHub PR interaction through `octo.nvim`
- AI-assisted editor workflow through `opencode.nvim`
- C/C++ highlighting and diagnostics through Treesitter and `clangd`
- Git workflow through Fugitive and Gitsigns
- VS Code task execution through `vs-tasks.nvim`
- Integrated terminal through ToggleTerm

## Explorer

- `<leader>e`: open/focus Neo-tree at the project root
- `<leader>E`: close Neo-tree

## Sessions and closing

Neovim keeps normal quit behavior for editor windows: `:q` closes the current window and `:qa` exits Neovim. To close the current file buffer while keeping the editor layout and Neo-tree open, use `:BufferClose`, `:Bd`, or `<leader>x`. Use `:BufferClose!`, `:Bd!`, or `<leader>X` to force-close a modified buffer.

Project sessions are saved automatically and restored when Neovim starts without explicit file arguments.

- `<leader>qs`: restore the current project session
- `<leader>ql`: restore the last session
- `<leader>qd`: stop saving the current session

## Tasks

Project tasks from `.vscode/tasks.json` are available in Neovim through VS Tasks:

```vim
:lua require("vstask").tasks()
```

Useful mappings:

- `<leader>tr`: select and run a VS Code task
- `<leader>tt`: show running and completed task jobs
- `<leader>ti`: edit task input variables
- `<leader>tl`: run a launch configuration
- `<leader>ts`: run an ad-hoc shell task

Inside the task picker:

- `<Enter>`: run task in a horizontal terminal split
- `<C-v>`: run task in a vertical split
- `<C-t>`: run task in a new tab
- `<C-b>`: run task in the background

## opencode

`opencode.nvim` connects Neovim to the `opencode` CLI. Install `opencode` in the devcontainer and run `:checkhealth opencode` if the integration does not start.

Useful mappings:

- `<leader>oa`: ask opencode with the current cursor or visual selection as context
- `<leader>oo`: open the opencode action picker
- `<leader>h`: show an opencode LSP hover explanation for the symbol under the cursor
- `<leader>on`: start a new opencode session
- `<leader>os`: select an opencode session
- `<leader>ou`: undo the last opencode change
- `<leader>or`: redo the last undone opencode change
- `<leader>oi`: interrupt the current opencode request
- `<leader>op`: submit the current opencode prompt
- `<leader>oc`: clear the current opencode prompt
- `<leader>oU` / `<leader>oD`: scroll the opencode TUI up or down
- `go{motion}`: add a motion range to opencode
- `goo`: add the current line to opencode

## Debugging

Debugging uses `.vscode/launch.json` as the source of truth where possible. The native simulator workflow starts the existing VS Code pre-launch task, waits for the gdbserver on `127.0.0.1:4112`, then attaches through `nvim-dap`.

Useful mappings:

- `<F5>`: start `Debug native_sim (Clang)` or continue an active debug session
- `<F9>`: toggle breakpoint
- `<F10>`: step over
- `<F11>`: step into
- `<S-F11>`: step out
- `<leader>dn`: start `Debug native_sim (Clang)`
- `<leader>du`: toggle debug UI
- `<leader>dr`: open debug REPL

The first start installs the C/C++ debug adapter through Mason (`cpptools`). If the adapter is not ready yet, run:

```vim
:MasonInstall cpptools
```

## C/C++ compile commands

`clangd` automatically uses the first existing `compile_commands.json` from common build directories. To force a specific build directory:

```sh
export NVIM_CLANGD_COMPILE_COMMANDS_DIR=/path/to/build-directory
nvim
```
