# Tmux Removal + Simulation Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove tmux from shell-hopper startup so nvim runs in a plain terminal, and route simulation launch (F5/tasks) through a WSL bridge that opens a dedicated Windows Terminal tab.

**Architecture:** A file-based bridge uses the shared `/home/user/west_workspace/` volume (visible identically from WSL and the Docker container) as an IPC channel. nvim writes a trigger file; a background watcher in WSL (which has Windows interop) reads it and opens `wt.exe new-tab` pointing at `devcontainer exec`. shell-hopper starts this watcher alongside nvim and kills it when nvim exits.

**Tech Stack:** bash (shellhopper + bridge), Lua (nvim), wt.exe (Windows Terminal CLI), devcontainer CLI

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `~/.local/bin/shellhopper` *(WSL)* | Modify | Disable tmux default, start/stop bridge around nvim |
| `~/.local/bin/shellhopper-sim-bridge` *(WSL)* | Create | Bridge watcher: polls trigger file, opens wt.exe tab |
| `lua/config/vscode_debug.lua` | Modify | Write trigger file instead of `tmux new-window` |

> **⚠️ WSL tasks** (Tasks 1–2) must be run from a WSL terminal, not the devcontainer.

---

### Task 1: Create `shellhopper-sim-bridge` in WSL

**Files:**
- Create: `~/.local/bin/shellhopper-sim-bridge` *(WSL)*

- [ ] **Step 1: Open a WSL terminal** (separate from the devcontainer)

- [ ] **Step 2: Write the bridge script**

```bash
cat > ~/.local/bin/shellhopper-sim-bridge << 'EOF'
#!/usr/bin/env bash
# shellhopper-sim-bridge
# Runs in WSL alongside shellhopper. Watches for a trigger file written by
# nvim (inside the devcontainer) and opens a new Windows Terminal tab that
# connects to the container and runs the simulation command.
#
# Args:
#   $1  trigger file path  (e.g. /home/user/west_workspace/.shellhopper-sim-trigger)
#   $2  devcontainer workspace-folder path (e.g. /home/user/west_workspace/qmx63_firmware_main)

set -uo pipefail

TRIGGER_FILE="${1:?trigger file path required}"
TARGET="${2:?devcontainer workspace path required}"
SIM_SCRIPT="${TRIGGER_FILE%/*}/.shellhopper-sim-script.sh"

cleanup() {
    rm -f "$TRIGGER_FILE" "$SIM_SCRIPT"
}
trap cleanup EXIT INT TERM

while true; do
    if [[ -f "$TRIGGER_FILE" ]]; then
        local_cmd=$(cat "$TRIGGER_FILE" 2>/dev/null || true)
        rm -f "$TRIGGER_FILE"

        if [[ -n "$local_cmd" ]]; then
            # Write command to a script on the shared volume (accessible from container)
            printf '#!/bin/bash\n%s\n' "$local_cmd" > "$SIM_SCRIPT"
            chmod +x "$SIM_SCRIPT"

            # Open a new Windows Terminal tab: WSL -> devcontainer exec -> sim script
            wt.exe new-tab -- \
                bash -lc "devcontainer exec --workspace-folder $(printf '%q' "$TARGET") bash -lc 'bash $(printf '%q' "$SIM_SCRIPT")'" &
        fi
    fi
    sleep 0.3
done
EOF
chmod +x ~/.local/bin/shellhopper-sim-bridge
```

- [ ] **Step 3: Verify the script is executable**

```bash
ls -la ~/.local/bin/shellhopper-sim-bridge
```

Expected: `-rwxr-xr-x ... shellhopper-sim-bridge`

---

### Task 2: Modify `shellhopper` in WSL

**Files:**
- Modify: `~/.local/bin/shellhopper` *(WSL)*

Two changes:
1. Default `tmux_enabled` to `0`
2. In the `devcontainer` case (no-tmux branch): start bridge, run nvim directly (not via `exec`), then kill bridge

- [ ] **Step 1: Change tmux default to 0**

Open `~/.local/bin/shellhopper`, find line:
```bash
tmux_enabled="${SHELLHOPPER_TMUX:-1}"
```
Change to:
```bash
tmux_enabled="${SHELLHOPPER_TMUX:-0}"
```

- [ ] **Step 2: Replace the devcontainer no-tmux branch**

Find this block in `launch_entry()`:
```bash
    devcontainer)
      if ! command -v devcontainer >/dev/null 2>&1; then
        log "devcontainer CLI not found. Install it with: npm install -g @devcontainers/cli"
        exit 1
      fi

      devcontainer up --workspace-folder "$target"
      if [[ "$tmux_enabled" == "1" ]]; then
        inner_command="$(workspace_command "$workspace" "$command")"
        shell_inner_command="$(workspace_command "$workspace" "bash")"
        run bash -lc "$(tmux_command "$name" "devcontainer exec --workspace-folder $(printf '%q' "$target") bash -lc $(printf '%q' "$inner_command")" "devcontainer exec --workspace-folder $(printf '%q' "$target") bash -lc $(printf '%q' "$shell_inner_command")")"
      else
        run devcontainer exec --workspace-folder "$target" bash -lc "$(workspace_command "$workspace" "$command")"
      fi
      ;;
```

Replace with:
```bash
    devcontainer)
      if ! command -v devcontainer >/dev/null 2>&1; then
        log "devcontainer CLI not found. Install it with: npm install -g @devcontainers/cli"
        exit 1
      fi

      devcontainer up --workspace-folder "$target"
      if [[ "$tmux_enabled" == "1" ]]; then
        local inner_command shell_inner_command
        inner_command="$(workspace_command "$workspace" "$command")"
        shell_inner_command="$(workspace_command "$workspace" "bash")"
        run bash -lc "$(tmux_command "$name" "devcontainer exec --workspace-folder $(printf '%q' "$target") bash -lc $(printf '%q' "$inner_command")" "devcontainer exec --workspace-folder $(printf '%q' "$target") bash -lc $(printf '%q' "$shell_inner_command")")"
      else
        local sim_trigger bridge_pid
        sim_trigger="${target}/.shellhopper-sim-trigger"
        rm -f "$sim_trigger"
        bridge_pid=""

        if command -v shellhopper-sim-bridge >/dev/null 2>&1; then
          shellhopper-sim-bridge "$sim_trigger" "$target" &
          bridge_pid=$!
        fi

        devcontainer exec --workspace-folder "$target" bash -lc "$(workspace_command "$workspace" "$command")" || true

        if [[ -n "$bridge_pid" ]]; then
          kill "$bridge_pid" 2>/dev/null || true
          wait "$bridge_pid" 2>/dev/null || true
        fi
        rm -f "$sim_trigger"
      fi
      ;;
```

- [ ] **Step 3: Verify shellhopper syntax**

```bash
bash -n ~/.local/bin/shellhopper && echo "syntax ok"
```

Expected: `syntax ok`

- [ ] **Step 4: Test dry-run shows no tmux**

```bash
shellhopper --dry-run --list
```

Expected: entries listed WITHOUT `tmux:` prefix in command column.

---

### Task 3: Modify `vscode_debug.lua` — write trigger file

**Files:**
- Modify: `lua/config/vscode_debug.lua` (in the devcontainer, nvim-config repo)

Replace the `run_vscode_task` function so that when the bridge is available (trigger file path is writable), it writes the command to the trigger instead of using `tmux new-window` or vstask/toggleterm.

- [ ] **Step 1: Open the file in nvim**

```
nvim /home/user/.config/nvim/lua/config/vscode_debug.lua
```

- [ ] **Step 2: Replace `run_vscode_task`**

Find and replace the entire `run_vscode_task` function. The new version:

```lua
local SIM_TRIGGER = (vim.env.WEST_WORKSPACE or "/home/user/west_workspace")
  .. "/.shellhopper-sim-trigger"

local function run_vscode_task(label)
  local parse = require("vstask.Parse")
  local job   = require("vstask.Job")
  local tasks = parse.Tasks()
  local task  = find_task_by_label(tasks, label)

  if task == nil then
    notify("VS Code task not found: " .. label, vim.log.levels.ERROR)
    return false
  end

  local cmd = build_task_cmd(task, tasks, job)
  if cmd == "" then
    notify("Empty command for task: " .. label, vim.log.levels.ERROR)
    return false
  end

  -- If the sim-bridge is active (shellhopper started without tmux), write the
  -- trigger file. The WSL bridge process picks it up within ~300 ms and opens
  -- a new Windows Terminal tab running the simulation inside the devcontainer.
  if vim.fn.filewritable(vim.fn.fnamemodify(SIM_TRIGGER, ":h")) == 2 then
    local f = io.open(SIM_TRIGGER, "w")
    if f then
      f:write(cmd)
      f:close()
      notify("Starting " .. label .. " in new terminal tab…")
      return true
    end
  end

  -- Fallback when no bridge (e.g. plain shell without shellhopper):
  -- run in outer tmux window if inside tmux, else use toggleterm.
  if vim.env.TMUX then
    local tmpfile = vim.fn.tempname() .. ".sh"
    local tf = io.open(tmpfile, "w")
    if tf then
      tf:write("#!/bin/bash\n" .. cmd .. "\n")
      tf:close()
      os.execute("chmod +x " .. tmpfile)
      local win_name = label:gsub("[%(%)%s]+", "-"):lower():sub(1, 20)
      vim.fn.system(string.format("tmux new-window -n %s %s",
        vim.fn.shellescape(win_name), vim.fn.shellescape(tmpfile)))
      vim.defer_fn(function() os.remove(tmpfile) end, 600000)
      return true
    end
  end

  -- Last resort: toggleterm inside nvim
  if task.dependsOn ~= nil then
    job.run_dependent_tasks(task, tasks)
  else
    job.start_job({
      label     = task.label,
      command   = cmd,
      silent    = false,
      watch     = false,
      terminal  = true,
      direction = "horizontal",
    })
  end
  return true
end
```

- [ ] **Step 3: Verify `build_task_cmd` is defined above `run_vscode_task`**

Search the file for `local function build_task_cmd`. It should already exist from the previous session. If not, add it before `run_vscode_task`:

```lua
local function build_task_cmd(task, tasks, job)
  local commands = {}
  local deps = type(task.dependsOn) == "string" and { task.dependsOn } or task.dependsOn or {}
  for _, dep_label in ipairs(deps) do
    local dep = find_task_by_label(tasks, dep_label)
    if dep then
      table.insert(commands, job.clean_command(dep.command, dep.options))
    end
  end
  if task.command then
    table.insert(commands, job.clean_command(task.command, task.options))
  end
  return table.concat(commands, " && ")
end
```

- [ ] **Step 4: Remove the old tmux new-window block if it still exists**

Search for `tmux new-window` in the file. If found inside `run_vscode_task`, the replacement in Step 2 already handles it. Double-check there are no duplicate definitions of `run_vscode_task`.

---

### Task 4: Commit nvim config changes

**Files:**
- Modify: `lua/config/vscode_debug.lua`

- [ ] **Step 1: Stage and commit**

```bash
cd /home/user/.config/nvim
git add lua/config/vscode_debug.lua
git commit -m "feat: route sim preLaunchTask through shellhopper-sim-bridge trigger file

When nvim is started via shellhopper (no outer tmux), writes the
simulation command to a shared trigger file that the WSL bridge
process picks up and opens in a new Windows Terminal tab.
Falls back to tmux new-window or toggleterm if bridge unavailable."
```

- [ ] **Step 2: Push**

```bash
git push origin main
```

---

### Task 5: End-to-end test

- [ ] **Step 1: Open a WSL terminal (not the devcontainer)**

Verify the bridge and shellhopper are in place:
```bash
ls -la ~/.local/bin/shellhopper-sim-bridge
bash -n ~/.local/bin/shellhopper && echo "shellhopper syntax ok"
```

- [ ] **Step 2: Launch via shellhopper**

```
shellhopper
```

Select the devcontainer entry. nvim should open **without** a surrounding tmux session. The status bar should NOT show a tmux indicator. The title bar should show the project name directly.

- [ ] **Step 3: Verify bridge is running**

In a separate WSL terminal (do NOT exit nvim):
```bash
pgrep -a shellhopper-sim-bridge
```

Expected: a process listed with the trigger path and target as args.

- [ ] **Step 4: Test task execution**

In nvim, press `<Space>tr`, select any build task (e.g. "Build native_sim (Clang)").

Expected: a new Windows Terminal tab opens running that task inside the devcontainer.

- [ ] **Step 5: Test F5 debug launch**

In nvim, press `F5`.

Expected:
- A new Windows Terminal tab opens running `native_sim_tmux.sh --gdbserver` (builds, then shows simulation panels)
- After gdbserver is ready, nvim's DAP connects and opens the left-panel debug UI (Scopes/Stack/Breakpoints)
- The simulation tab shows the native-sim tmux panels (Display, GPIO Emulator, Shell, etc.)
- nvim tab and simulation tab are separate Windows Terminal tabs — switch with Ctrl+Tab

- [ ] **Step 6: Verify cleanup on exit**

Exit nvim (`:q`). In the WSL terminal:
```bash
pgrep shellhopper-sim-bridge && echo "still running" || echo "cleaned up"
ls /home/user/west_workspace/.shellhopper-sim-trigger 2>/dev/null && echo "trigger left behind" || echo "trigger cleaned up"
```

Expected: both show `cleaned up` / `trigger cleaned up`.
