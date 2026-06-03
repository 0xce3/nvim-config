# Neovim config

Personal Neovim configuration for a devcontainer-based development workflow.

## Restore in a fresh container

```sh
git clone https://github.com/0xce3/nvim-config.git ~/.config/nvim
nvim
```

`lazy.nvim` bootstraps itself on first start and installs the configured plugins.

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
- C/C++ highlighting and diagnostics through Treesitter and `clangd`
- Git workflow through Fugitive and Gitsigns
- VS Code task execution through `vs-tasks.nvim`
- Integrated terminal through ToggleTerm

## Explorer

- `<leader>e`: open/focus Neo-tree at the project root
- `<leader>E`: close Neo-tree

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

## C/C++ compile commands

`clangd` automatically uses the first existing `compile_commands.json` from common build directories. To force a specific build directory:

```sh
export NVIM_CLANGD_COMPILE_COMMANDS_DIR=/path/to/build-directory
nvim
```
