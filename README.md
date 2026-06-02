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
- VS Code task execution through `overseer.nvim`
- Integrated terminal through ToggleTerm

## Tasks

Project tasks from `.vscode/tasks.json` are available in Neovim through Overseer:

```vim
:OverseerRun
```

Useful mappings:

- `<leader>tr`: select and run a task
- `<leader>tt`: toggle the task list
- `<leader>ta`: run an action on a task
- `<leader>ts`: run an ad-hoc shell task

## C/C++ compile commands

`clangd` automatically uses the first existing `compile_commands.json` from common build directories. To force a specific build directory:

```sh
export NVIM_CLANGD_COMPILE_COMMANDS_DIR=/path/to/build-directory
nvim
```
