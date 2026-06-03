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
      "name": "Debug native_sim (Clang)",
      "type": "cppdbg",
      "request": "launch",
      "preLaunchTask": "Run native_sim with gdbserver (Clang)",
      "postDebugTask": "Stop native_sim",
      "program": "${workspaceFolder}/main_app/build_native_clang/zephyr/zephyr.exe",
      "stopAtEntry": true,
      "cwd": "${workspaceFolder}/main_app",
      "MIMode": "gdb",
      "miDebuggerPath": "/usr/bin/gdb",
      "miDebuggerServerAddress": "127.0.0.1:4112",
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
  assert(dap_config.name == "Debug native_sim (Clang)", "unexpected launch name")
  assert(dap_config.type == "cppdbg", "unexpected adapter type")
  assert(dap_config.program:match("/main_app/build_native_clang/zephyr/zephyr.exe$"), "program path not expanded")
  assert(dap_config.cwd:match("/main_app$"), "cwd not expanded")
  assert(dap_config.miDebuggerPath == "/usr/bin/gdb", "unexpected gdb path")
  assert(dap_config.miDebuggerServerAddress == "127.0.0.1:4112", "unexpected gdbserver address")
end' +qa

printf 'debug_config_test.sh: ok\n'
