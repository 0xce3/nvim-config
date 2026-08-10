#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/.vscode"
cat > "$fixture_root/.vscode/launch.json" <<'JSONC'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug sample app",
      "type": "cppdbg",
      "request": "launch",
      "preLaunchTask": "Start debug server",
      "postDebugTask": "Stop debug server",
      "program": "${workspaceFolder}/app/build/app.elf",
      "stopAtEntry": true,
      "cwd": "${workspaceFolder}/app",
      "MIMode": "gdb",
      "miDebuggerPath": "/usr/bin/gdb",
      "miDebuggerServerAddress": "127.0.0.1:4112",
    }
  ]
}
JSONC

cat > "$fixture_root/.vscode/tasks.json" <<'JSONC'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Create tag",
      "type": "shell",
      "command": "bash",
      "args": [
        "-lc",
        "printf '%s:%s' '${input:tagVersion}' '${input:tagMessage}'"
      ]
    }
  ],
  "inputs": [
    {
      "id": "tagVersion",
      "type": "promptString",
      "description": "Version",
      "default": "v1.0.0"
    },
    {
      "id": "tagMessage",
      "type": "promptString",
      "description": "Message"
    }
  ]
}
JSONC

cd "$fixture_root"
nvim --headless -u "$repo_root/init.lua" +'lua do
  local debug_config = require("config.vscode_debug")
  local launches = debug_config.load_launches(vim.uv.cwd())
  assert(#launches == 1, "expected one launch config")
  local dap_config = debug_config.build_dap_config(launches[1], vim.uv.cwd())
  assert(dap_config.name == "Debug sample app", "unexpected launch name")
  assert(dap_config.type == "cppdbg", "unexpected adapter type")
  assert(dap_config.program:match("/app/build/app%.elf$"), "program path not expanded")
  assert(dap_config.cwd:match("/app$"), "cwd not expanded")
  assert(dap_config.miDebuggerPath == "/usr/bin/gdb", "unexpected gdb path")
  assert(dap_config.miDebuggerServerAddress == "127.0.0.1:4112", "unexpected gdbserver address")
end' +qa

cat > "$fixture_root/task_input_test.lua" <<'LUA'
local prompts = { ["Version: "] = "v2.3.4", ["Message: "] = "Release 2.3.4" }
vim.ui.input = function(opts, callback)
  assert(opts.icon_pos == false, "task input icon must be disabled")
  assert(opts.expand == false, "task input resizing must be disabled")
  callback(prompts[opts.prompt])
end

local command
package.loaded["vstask.Job"] = {
  clean_command = function(value, _, args)
    return value .. " " .. table.concat(args, " ")
  end,
  start_job = function(opts) command = opts.command end,
}

local debug_config = require("config.vscode_debug")
assert(debug_config.run_task("Create tag"), "expected task to start")
assert(command == "bash -lc printf '%s:%s' 'v2.3.4' 'Release 2.3.4'", "task inputs were not expanded: " .. tostring(command))
vim.cmd.quitall()
LUA

nvim --headless -u "$repo_root/init.lua" -l "$fixture_root/task_input_test.lua"

printf 'debug_config_test.sh: ok\n'
