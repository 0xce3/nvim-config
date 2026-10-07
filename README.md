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

**Host (WSL / Linux / macOS):** Neovim 0.11+, tmux 3.6+, `git`, `curl`, `ripgrep`, `fd`,
  `python3`, `node`/`npm`, a C compiler, `make`, Docker, and a Nerd Font for
  icons. Treesitter parsers are compiled locally for the host system.

**Devcontainer:** Toolchain (clangd, cmake, gcc, ninja, …) – defined in your
  project's `.devcontainer/devcontainer.json` / Dockerfile.

  nvim on the host connects remotely to the devcontainer for LSP, builds,
  and debugging. The host itself does not need the toolchain.

## One-command install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xce3/nvim-config/main/install.sh)"
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
| Theme/UI | `ellisonleao/gruvbox.nvim`, `lualine.nvim`, `which-key.nvim` | Colors, statusline, key hints |
| Explorer | `nvim-telescope/telescope-file-browser.nvim` | File browser on `<leader>e` |
| Find | `snacks.nvim`, `telescope.nvim` | Fast project search and shared picker backend |
| LSP | `nvim-lspconfig`, `mason.nvim`, `mason-tool-installer.nvim` | Language servers and tooling |
| Completion | `nvim-cmp`, `LuaSnip` | Completion and snippets |
| Syntax | `nvim-treesitter/nvim-treesitter`, `rainbow-delimiters.nvim` | Parsing, highlighting, delimiters |
| Git | `vim-fugitive`, `gitsigns.nvim`, `octo.nvim`, `snacks.nvim` | Git status, hunks, GitHub PRs, lazygit |
| Debug | `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text` | DAP debugging |
| Tasks | `vs-tasks.nvim` | Run `.vscode/tasks.json` and launch configs |
| HTTP | `kulala.nvim` | Run generated `.http` API requests outside project repos |
| AI | `opencode.nvim` | Optional opencode integration |

Exact pinned versions live in `lazy-lock.json`.

## Devcontainer (Remote Workflow)

Interactive `nvim` and `nvim .` starts first select the local or remote runtime,
then use a project-specific tmux session there. The tmux window bar is at the top;
AstroNvim's statusline stays at the bottom. Windows are `1:nvim`, `2:bash`, and
`3:tasks` (created on the first task).
The existing local/remote choice appears before tmux starts. In remote mode,
tmux, its Neovim UI client, Bash, and tasks run in the selected container.
Local mode uses host Bash and host tasks. Python environment activation follows
the shell startup configuration and the task's existing environment setup.

Use `Ctrl+1`, `Ctrl+2`, or `Ctrl+3` to select a window. `<leader>tb` switches
from Neovim to Bash, and `<leader>tj` / F12 selects the task window. Task results
continue to update the AstroNvim statusline. Tasks start in window 3 without
changing the active window; switch there manually when needed. Window 0 is not
used, and windows 4 through 9 are available for additional shells or tools.
Interactive Neovim task-buffer diagnostic navigation applies only to the
fallback embedded terminal. Debug
server terminals remain embedded for the existing DAP lifecycle integration.

`Ctrl+1` through `Ctrl+9` select tmux windows directly, without the prefix.
Windows Terminal must forward these keys as CSI-u sequences using `sendInput`:
`Ctrl+1` sends `\u001b[49;5u`, and so on through `Ctrl+9`, which sends
`\u001b[57;5u`. `Ctrl+0` retains Windows Terminal's default font-size reset.
The bindings are consumed by tmux before reaching Neovim or Bash.

`Ctrl+Left` and `Ctrl+Right` select the previous and next tmux windows, wrapping
at the ends and skipping unused numbers. Windows Terminal forwards these using
`sendInput` sequences `\u001b[1;5D` and `\u001b[1;5C`, replacing its pane-focus
bindings on those keys. `Ctrl+1` through `Ctrl+9` still select windows directly.

In the `bash` and `tasks` windows, PageUp enters tmux scrollback and scrolls up
one page; PageDown scrolls down and returns to the live prompt at the bottom.
Up/Down in Bash continue to select previous/next shell commands: from scrollback
they first leave copy mode and then forward the arrow key to Bash. PageUp/PageDown in the
editor window are still forwarded to Neovim. Escape or `q` can also leave copy
mode with the standard tmux bindings.

Mouse support is enabled. The wheel scrolls tmux output, and Bash/task windows
have a draggable scrollbar on the right when scrollback exists. Its track uses
the terminal's default background, and it hides when there is no scrollback.
Neovim keeps its own mouse handling
and does not receive a tmux scrollbar. New panes retain up to 50,000 lines.
The scrollback belongs to tmux rather than Windows Terminal's outer scrollbar.
Native pane scrollbars require tmux 3.6 or newer. Container setup installs the
pinned, checksum-verified 3.6 release if necessary; on an older Linux host run
`bash ~/.config/nvim/bin/install-tmux`. Existing tmux servers must be closed
before the new binary and scrollbar settings take effect.

Tmux and Python 3 must be installed in the selected runtime (the installers
include tmux). `NVIM_NO_TMUX=1 nvim .` bypasses the automatic session. Neovim
invoked from an embedded terminal or with CLI
options (for example `--headless` or `--server`) is not wrapped in a new session.
The editor owns its workspace session: closing Neovim also closes its Bash and
task windows. Closing or detaching the last tmux client destroys the session,
so `Ctrl+b`, then `d` exits rather than leaving a background workspace behind.
Multiple clients may share a live session; disconnecting one does not destroy
it while another is still attached. The remote launcher also stops its port and
file bridges and shuts down the headless server once no UI is using it. A
terminal disconnect uses Neovim's signal-preservation path for modified buffers.

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
| `<leader>e` | Yazi in a floating window |
| `<leader>x` / `<leader>X` | Close buffer / force close buffer; also closes terminal buffers |
| `<Tab>` / `<S-Tab>` | Open buffer picker / previous listed buffer |
| `<leader>gg` | Fugitive Git status |
| `<leader>gl` | Lazygit in a dedicated terminal buffer |
| `<leader>gL` | Lazygit in a floating Snacks window |
| `<leader>gn` / `<leader>gp` | Next / previous Git hunk |
| `<leader>fc` | Pick active `compile_commands.json` for clangd |
| `<leader>tr` | Run VS Code task |
| `<leader>tl` | Run VS Code launch config |
| `<leader>tj` / `<F12>` | Toggle reusable terminal buffer |
| `<leader>tq` | Leave reusable terminal buffer |
| `<F5>` | Continue debug session or pick launch config |
| `<F9>` | Toggle breakpoint |
| `<F10>` / `<F11>` / `<S-F11>` | Step over / into / out |
| `<leader>dl` | Pick debug launch config |
| `<leader>dq` | Stop debug session and clean debug UI buffers |
| `<leader>du` | Toggle debug UI |
| `<leader>dr` | Open debug REPL |
| `<Esc><Esc>` | Leave terminal mode |
| `<C-h/j/k/l>` | Move between Neovim windows, also from terminal mode |
| `<leader>tb` | Switch to the external tmux Bash window |
| `<leader>r` | Run request under cursor |
| `<leader>rg` | Generate external `.http` workspace from OpenAPI |
| `<leader>ro` | Open external `.http` workspace |
| `<leader>rd` | Delete external `.http` workspace |
| `<leader>rp` | Pick OpenAPI file and generate `.http` workspace |

## HTTP Workspaces

`kulala.nvim` runs `.http` API requests from Neovim. `:HttpWorkspaceGenerate`
searches the current project for `openapi.yaml`, `openapi.yml`, `swagger.yaml`,
or `swagger.yml`, asks for a workspace name, and generates `<name>.http` outside
the project repository. `:HttpWorkspaceGenerate smoke` skips the prompt and
creates `smoke.http` directly.

`:HttpWorkspaceOpen` lists existing HTTP workspaces for the current project and
opens the selected file.

`:HttpWorkspaceDelete` lists existing HTTP workspaces for the current project and
deletes the selected file after confirmation.

When the OpenAPI contains a login/authenticate endpoint returning
`access_token`, the generated login request stores a global Kulala
`Authorization` header for following requests. Run the login request once before
calling protected endpoints.

Generated files live under Neovim state, or under `.nvim-http-workspaces` next to
the devcontainer workspace. They are local scratch files and are not written into
application repositories.

The generator uses `PyYAML`; `bin/nvim-dev` installs the container package where
possible.

## VS Code Tasks And Launches

Tasks are read from `.vscode/tasks.json` through `vs-tasks.nvim`. Task commands
run in a single reusable terminal buffer shown like any other buffer.

Terminal buffers can be closed with `<leader>x`, `q`, or `:q` from normal mode.

Debug launches are read from the current project's `.vscode/launch.json` and
executed through `nvim-dap`/`cpptools`. Project-specific target names, paths,
ports, and toolchain commands belong in the project repository or local files,
not in this public config.

`:DebugLaunch` runs the first launch config by default, or a named config when
provided. `<leader>dl` opens a picker for all launch configs. `<F5>` continues an
active session or opens the launch picker.

Native/local GDB launches work without `miDebuggerServerAddress`:

```jsonc
{
  "name": "Native simulator",
  "type": "cppdbg",
  "request": "launch",
  "program": "${workspaceFolder}/build/app",
  "cwd": "${workspaceFolder}",
  "MIMode": "gdb",
  "miDebuggerPath": "/usr/bin/gdb",
  "stopAtEntry": false
}
```

Remote hardware/debug-probe sessions use `miDebuggerServerAddress`. If the
server is not reachable, `preLaunchTask` is started and Neovim waits for the TCP
port before attaching. The default wait is 30 seconds and can be overridden per
launch with `serverReadyTimeout` in milliseconds, or globally with
`NVIM_DAP_SERVER_TIMEOUT_MS`:

```jsonc
{
  "name": "Remote target",
  "type": "cppdbg",
  "request": "launch",
  "program": "${workspaceFolder}/build/firmware.elf",
  "cwd": "${workspaceFolder}",
  "MIMode": "gdb",
  "miDebuggerPath": "arm-none-eabi-gdb",
  "miDebuggerServerAddress": "127.0.0.1:2331",
  "serverReadyTimeout": 15000,
  "preLaunchTask": "Start GDB server",
  "postDebugTask": "Stop GDB server",
  "setupCommands": [
    { "text": "target remote 127.0.0.1:2331" },
    { "text": "monitor reset halt" },
    { "text": "load" }
  ]
}
```

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
