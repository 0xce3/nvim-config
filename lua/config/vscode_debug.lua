local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "debug" })
end

function M.find_task_root()
  local cwd = vim.uv.cwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")

  local function valid_root(path)
    return path and path ~= "" and vim.fn.isdirectory(path) == 1 and vim.fn.filereadable(vim.fs.joinpath(path, ".vscode", "tasks.json")) == 1
  end

  if valid_root(vim.env.NVIM_TASK_WORKSPACE_FOLDER) then
    return vim.env.NVIM_TASK_WORKSPACE_FOLDER
  end

  local home = vim.env.HOME or ""
  for _, base in ipairs({ "workspace", "workspaces", "west" .. "_" .. "workspace" }) do
    local candidate = vim.fs.joinpath(home, base, project_name)
    if valid_root(candidate) then
      return candidate
    end
  end

  for name, type_ in vim.fs.dir(cwd) do
    if type_ == "directory" and name:match("^%.") and name:lower():find("workspace", 1, true) then
      local mirrored = vim.fs.joinpath(cwd, name, project_name)
      if valid_root(mirrored) then
        return mirrored
      end
    end
  end

  local matches = vim.fs.find({ ".vscode", ".git" }, { upward = true, path = cwd })
  if #matches == 0 then
    return cwd
  end
  return vim.fs.dirname(matches[1])
end

function M.decode_jsonc(text)
  local out = {}
  local i = 1
  local len = #text
  local in_string = false
  local quote = nil
  local escaped = false

  while i <= len do
    local ch = text:sub(i, i)
    local next_ch = text:sub(i + 1, i + 1)

    if in_string then
      table.insert(out, ch)
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == quote then
        in_string = false
        quote = nil
      end
      i = i + 1
    elseif ch == '"' or ch == "'" then
      in_string = true
      quote = ch
      table.insert(out, ch)
      i = i + 1
    elseif ch == "/" and next_ch == "/" then
      i = i + 2
      while i <= len and text:sub(i, i) ~= "\n" do
        i = i + 1
      end
    elseif ch == "/" and next_ch == "*" then
      i = i + 2
      while i <= len and not (text:sub(i, i) == "*" and text:sub(i + 1, i + 1) == "/") do
        i = i + 1
      end
      i = i + 2
    else
      table.insert(out, ch)
      i = i + 1
    end
  end

  local without_comments = table.concat(out)
  local without_trailing_commas = without_comments:gsub(",%s*([}%]])", "%1")
  return vim.json.decode(without_trailing_commas)
end

function M.expand_vscode_vars(value, task_root)
  if type(value) ~= "string" then
    return value
  end

  value = value:gsub("%${workspaceFolder}", task_root)
  value = value:gsub("%${workspaceRoot}", task_root)
  value = value:gsub("%${env:([^}]+)}", function(name)
    return vim.env[name] or ""
  end)
  return value
end

function M.load_launches(task_root)
  local launch_path = vim.fs.joinpath(task_root, ".vscode", "launch.json")
  if vim.fn.filereadable(launch_path) ~= 1 then
    return {}
  end

  local text = table.concat(vim.fn.readfile(launch_path), "\n")
  local ok, parsed = pcall(M.decode_jsonc, text)
  if not ok or type(parsed) ~= "table" then
    notify("Could not parse " .. launch_path, vim.log.levels.ERROR)
    return {}
  end

  return parsed.configurations or {}
end

local function find_launch(name, task_root)
  for _, launch in ipairs(M.load_launches(task_root)) do
    if launch.name == name then
      return launch
    end
  end
  return nil
end

function M.open_debug_adapter_path()
  local candidates = {
    vim.fn.exepath("OpenDebugAD7"),
    vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "cpptools", "extension", "debugAdapters", "bin", "OpenDebugAD7"),
  }

  for _, candidate in ipairs(candidates) do
    if candidate ~= nil and candidate ~= "" and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return nil
end

function M.build_dap_config(launch, task_root)
  return {
    name = launch.name,
    type = "cppdbg",
    request = launch.request or "launch",
    program = M.expand_vscode_vars(launch.program, task_root),
    args = launch.args or {},
    stopAtEntry = launch.stopAtEntry == true,
    cwd = M.expand_vscode_vars(launch.cwd or task_root, task_root),
    environment = launch.environment or {},
    externalConsole = launch.externalConsole == true,
    MIMode = launch.MIMode or "gdb",
    miDebuggerPath = M.expand_vscode_vars(launch.miDebuggerPath or "/usr/bin/gdb", task_root),
    miDebuggerServerAddress = launch.miDebuggerServerAddress,
    setupCommands = launch.setupCommands or {},
  }
end

local function find_task_by_label(tasks, label)
  for _, task in ipairs(tasks or {}) do
    if task.label == label then
      return task
    end
  end
  return nil
end

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

function M.run_task(label)
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

  -- Run every VS Code task through the reusable in-Nvim terminal buffer.
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

function M.task_labels()
  local ok, parse = pcall(require, "vstask.Parse")
  if not ok then
    notify("vstask.Parse not available", vim.log.levels.ERROR)
    return {}
  end

  return vim.tbl_map(function(task)
    return task.label
  end, vim.tbl_filter(function(task)
    return type(task.label) == "string" and task.label ~= ""
  end, parse.Tasks()))
end

local recent_task_file = vim.fs.joinpath(vim.fn.stdpath("state"), "vscode-task-last.txt")

local function read_recent_task()
  local lines = vim.fn.readfile(recent_task_file)
  return lines[1]
end

local function write_recent_task(label)
  vim.fn.mkdir(vim.fn.fnamemodify(recent_task_file, ":h"), "p")
  vim.fn.writefile({ label }, recent_task_file)
end

function M.pick_task()
  local labels = M.task_labels()
  if #labels == 0 then
    notify("No VS Code tasks found", vim.log.levels.WARN)
    return
  end

  local favorites = {
    "Flash qmx63 (NS_SOSI) (GCC)",
    "Build qmx63 (NS_SOSI) (GCC)",
    "Rebuild qmx63 (NS_SOSI) (GCC)",
  }
  local recent = read_recent_task()
  local seen = {}
  local ordered = {}

  local function add(label)
    if label and not seen[label] and vim.tbl_contains(labels, label) then
      seen[label] = true
      table.insert(ordered, label)
    end
  end

  add(recent)
  for _, label in ipairs(favorites) do
    add(label)
  end
  for _, label in ipairs(labels) do
    add(label)
  end

  vim.ui.select(ordered, { prompt = "VS Code task" }, function(choice)
    if not choice then
      return
    end
    write_recent_task(choice)
    M.run_task(choice)
  end)
end

local function split_host_port(address)
  if type(address) ~= "string" then
    return nil, nil
  end

  local host, port = address:match("^([^:]+):(%d+)$")
  return host, tonumber(port)
end

local function check_tcp(host, port, callback)
  local tcp = vim.uv.new_tcp()
  tcp:connect(host, port, function(err)
    tcp:close()
    callback(err == nil)
  end)
end

local function wait_for_tcp(host, port, timeout_ms, callback)
  local started = vim.uv.now()
  local timer = vim.uv.new_timer()

  local function tick()
    check_tcp(host, port, function(open)
      if open then
        timer:stop()
        timer:close()
        callback(true)
        return
      end

      if vim.uv.now() - started >= timeout_ms then
        timer:stop()
        timer:close()
        callback(false)
      end
    end)
  end

  timer:start(0, 500, tick)
end

function M.run_launch(name)
  local dap = require("dap")
  local task_root = M.find_task_root()
  local launch = find_launch(name, task_root)
  if launch == nil then
    notify("Launch config not found: " .. name, vim.log.levels.ERROR)
    return
  end

  local adapter_path = M.open_debug_adapter_path()
  if adapter_path == nil then
    notify("C++ debug adapter missing. Run :MasonInstall cpptools and retry.", vim.log.levels.ERROR)
    return
  end

  local host, port = split_host_port(launch.miDebuggerServerAddress)
  if host == nil or port == nil then
    notify("Launch config has no miDebuggerServerAddress: " .. name, vim.log.levels.ERROR)
    return
  end

  dap.adapters.cppdbg = {
    id = "cppdbg",
    type = "executable",
    command = adapter_path,
    options = {
      detached = false,
    },
  }

  local config = M.build_dap_config(launch, task_root)

  check_tcp(host, port, function(open)
    vim.schedule(function()
      if open then
        dap.run(config)
        return
      end

      if type(launch.preLaunchTask) == "string" then
        notify("Starting " .. launch.preLaunchTask)
        if not M.run_task(launch.preLaunchTask) then
          return
        end
      end

      notify("Waiting for gdbserver on " .. launch.miDebuggerServerAddress)
      wait_for_tcp(host, port, 90000, function(ready)
        vim.schedule(function()
          if not ready then
            notify("gdbserver did not open " .. launch.miDebuggerServerAddress, vim.log.levels.ERROR)
            return
          end
          dap.run(config)
        end)
      end)
    end)
  end)
end

function M.stop_post_debug_task(name)
  local task_root = M.find_task_root()
  local launch = find_launch(name, task_root)
  if launch ~= nil and type(launch.postDebugTask) == "string" then
    M.run_task(launch.postDebugTask)
  end
end

function M.setup()
  local dap = require("dap")
  local dapui = require("dapui")
  local stopped_sessions = {}

  dapui.setup({
    layouts = {
      {
        elements = {
          { id = "scopes",      size = 0.40 },
          { id = "stacks",      size = 0.35 },
          { id = "breakpoints", size = 0.15 },
          { id = "watches",     size = 0.10 },
        },
        size = 40,
        position = "left",
      },
      {
        elements = {
          { id = "repl",    size = 0.5 },
          { id = "console", size = 0.5 },
        },
        size = 12,
        position = "bottom",
      },
    },
  })

  -- Open only the side panel on start; the reusable terminal owns task output.
  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open({ layout = 1, reset = true })
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end
  local function stop_post_debug_task_once(session)
    if session and session.config and session.config.name then
      local key = session.id or tostring(session)
      if stopped_sessions[key] then
        return
      end
      stopped_sessions[key] = true
      M.stop_post_debug_task(session.config.name)
    end
  end

  dap.listeners.after.event_terminated["post_debug_task"] = stop_post_debug_task_once
  dap.listeners.after.event_exited["post_debug_task"] = stop_post_debug_task_once

  local function continue_or_first_launch()
    if dap.session() ~= nil then
      dap.continue()
      return
    end

    local launches = M.load_launches(M.find_task_root())
    if #launches == 0 then
      notify("No VS Code launch configurations found", vim.log.levels.WARN)
      return
    end
    M.run_launch(launches[1].name)
  end

  local map = vim.keymap.set
  map("n", "<F5>", continue_or_first_launch, { desc = "Debug first launch / continue" })
  map("n", "<F9>", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<F10>", dap.step_over, { desc = "Step over" })
  map("n", "<F11>", dap.step_into, { desc = "Step into" })
  map("n", "<S-F11>", dap.step_out, { desc = "Step out" })
  map("n", "<leader>dc", dap.continue, { desc = "Debug continue" })
  map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug breakpoint" })
  map("n", "<leader>du", dapui.toggle, { desc = "Debug UI" })
  map("n", "<leader>dr", dap.repl.open, { desc = "Debug REPL" })
  vim.api.nvim_create_user_command("DebugLaunch", function(opts)
    local name = opts.args
    if name == "" then
      local launches = M.load_launches(M.find_task_root())
      if #launches == 0 then
        notify("No VS Code launch configurations found", vim.log.levels.WARN)
        return
      end
      name = launches[1].name
    end
    M.run_launch(name)
  end, {
    complete = function()
      return vim.tbl_map(function(launch)
        return launch.name
      end, M.load_launches(M.find_task_root()))
    end,
    desc = "Run a VS Code launch configuration",
    nargs = "?",
  })
end

return M
