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
  value = value:gsub("%${cwd}", vim.uv.cwd() or task_root)
  value = value:gsub("%${env:([^}]+)}", function(name)
    return vim.env[name] or ""
  end)
  return value
end

local function expand_vscode_value(value, task_root)
  if type(value) == "string" then
    return M.expand_vscode_vars(value, task_root)
  end
  if type(value) ~= "table" then
    return value
  end

  local expanded = {}
  for key, item in pairs(value) do
    expanded[key] = expand_vscode_value(item, task_root)
  end
  return expanded
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
  local request = launch.request or "launch"
  if request == "attach" and launch.processId == nil then
    request = "launch"
  end
  local program = launch.program or launch.executable or launch.target

  local config = {
    name = launch.name,
    type = "cppdbg",
    request = request,
    program = M.expand_vscode_vars(program, task_root),
    args = expand_vscode_value(launch.args or {}, task_root),
    stopAtEntry = launch.stopAtEntry == true,
    cwd = M.expand_vscode_vars(launch.cwd or task_root, task_root),
    environment = expand_vscode_value(launch.environment or {}, task_root),
    externalConsole = launch.externalConsole == true,
    MIMode = launch.MIMode or "gdb",
    miDebuggerPath = M.expand_vscode_vars(launch.miDebuggerPath or "/usr/bin/gdb", task_root),
    miDebuggerServerAddress = launch.miDebuggerServerAddress,
    setupCommands = expand_vscode_value(launch.setupCommands or {}, task_root),
    customLaunchSetupCommands = expand_vscode_value(launch.customLaunchSetupCommands, task_root),
    launchCompleteCommand = launch.launchCompleteCommand,
    sourceFileMap = expand_vscode_value(launch.sourceFileMap, task_root),
    symbolSearchPath = M.expand_vscode_vars(launch.symbolSearchPath, task_root),
    additionalSOLibSearchPath = M.expand_vscode_vars(launch.additionalSOLibSearchPath, task_root),
  }

  for _, key in ipairs({ "targetArchitecture", "processId", "coreDumpPath", "serverStarted", "filterStderr", "filterStdout" }) do
    if launch[key] ~= nil then
      config[key] = expand_vscode_value(launch[key], task_root)
    end
  end

  return config
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

local state_dir = vim.fn.stdpath("state")
local recent_task_file = vim.fs.joinpath(state_dir, "vscode-task-last.txt")
local favorites_file = vim.fs.joinpath(state_dir, "vscode-favorites.txt")

local function read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok and lines then
    return lines
  end
  return {}
end

local function write_file(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(lines, path)
end

local function read_recent_task()
  local lines = read_file(recent_task_file)
  return lines[1]
end

local function write_recent_task(label)
  write_file(recent_task_file, { label })
end

local function read_favorites()
  local lines = read_file(favorites_file)
  local set = {}
  for _, label in ipairs(lines) do
    set[label] = true
  end
  return set
end

local function write_favorites(set)
  local lines = {}
  for label, _ in pairs(set) do
    table.insert(lines, label)
  end
  table.sort(lines)
  write_file(favorites_file, lines)
end

function M.pick_task()
  local labels = M.task_labels()
  if #labels == 0 then
    notify("No VS Code tasks found", vim.log.levels.WARN)
    return
  end

  local recent = read_recent_task()
  local favorites = read_favorites()
  local seen = {}
  local ordered = {}

  local function add(label)
    if label and not seen[label] and vim.tbl_contains(labels, label) then
      seen[label] = true
      table.insert(ordered, label)
    end
  end

  add(recent)
  for _, label in ipairs(labels) do
    if favorites[label] then
      add(label)
    end
  end
  for _, label in ipairs(labels) do
    add(label)
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function make_finder()
    return finders.new_table({
      results = ordered,
      entry_maker = function(label)
        local icon = ""
        if favorites[label] then
          icon = "★ "
        end
        return {
          value = label,
          display = icon .. label,
          ordinal = (favorites[label] and "!" or " ") .. label,
        }
      end,
    })
  end

  pickers
    .new({}, {
      prompt_title = "VS Code task",
      finder = make_finder(),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection then
            return
          end
          write_recent_task(selection.value)
          M.run_task(selection.value)
        end)

        map("i", "<Tab>", function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          local label = selection.value
          if favorites[label] then
            favorites[label] = nil
          elseif vim.tbl_contains(labels, label) then
            favorites[label] = true
          end
          write_favorites(favorites)
          local picker = action_state.get_current_picker(prompt_bufnr)
          picker:refresh(make_finder(), { reset_prompt = false })
        end)
        return true
      end,
    })
    :find()
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

local function server_timeout_ms(launch)
  local timeout = tonumber(launch.serverReadyTimeout or vim.env.NVIM_DAP_SERVER_TIMEOUT_MS)
  if timeout ~= nil and timeout > 0 then
    return timeout
  end
  return 30000
end

local function find_elf_files(root)
  local matches = vim.fs.find(function(name, path)
    if not name:match("%.elf$") then
      return false
    end
    local rel = vim.fs.joinpath(path, name):sub(#root + 2)
    return rel:match("^build[^/]*/") ~= nil or rel:match("/build[^/]*/") ~= nil
  end, { path = root, type = "file", limit = 200 })

  table.sort(matches)
  return matches
end

local function fill_missing_program(config, task_root, callback)
  if type(config.program) == "string" and config.program ~= "" then
    callback(true)
    return
  end

  local elfs = find_elf_files(task_root)
  if #elfs == 0 then
    notify("Debug launch needs a program/executable path, and no .elf was found under build directories", vim.log.levels.ERROR)
    callback(false)
    return
  end

  if #elfs == 1 then
    config.program = elfs[1]
    notify("Using debug program: " .. vim.fn.fnamemodify(config.program, ":~:."))
    callback(true)
    return
  end

  vim.ui.select(elfs, {
    prompt = "Debug program (.elf)",
    format_item = function(path)
      return vim.fn.fnamemodify(path, ":~:.")
    end,
  }, function(choice)
    if choice == nil then
      callback(false)
      return
    end
    config.program = choice
    callback(true)
  end)
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

  dap.adapters.cppdbg = {
    id = "cppdbg",
    type = "executable",
    command = adapter_path,
    options = {
      detached = false,
    },
  }

  local config = M.build_dap_config(launch, task_root)
  local host, port = split_host_port(config.miDebuggerServerAddress)

  local function run_config()
    if config.request ~= "launch" then
      dap.run(config)
      return
    end

    fill_missing_program(config, task_root, function(ok)
      if ok then
        dap.run(config)
      end
    end)
  end

  local function run_after_prelaunch()
    if host == nil or port == nil then
      run_config()
      return
    end

    notify("Waiting for gdbserver on " .. config.miDebuggerServerAddress)
    wait_for_tcp(host, port, server_timeout_ms(launch), function(ready)
      vim.schedule(function()
        if not ready then
          notify("gdbserver did not open " .. config.miDebuggerServerAddress, vim.log.levels.ERROR)
          return
        end
        run_config()
      end)
    end)
  end

  if host == nil or port == nil then
    if type(launch.preLaunchTask) == "string" then
      notify("Starting " .. launch.preLaunchTask)
      if not M.run_task(launch.preLaunchTask) then
        return
      end
    end
    run_config()
    return
  end

  check_tcp(host, port, function(open)
    vim.schedule(function()
      if open then
        run_config()
        return
      end

      if type(launch.preLaunchTask) == "string" then
        notify("Starting " .. launch.preLaunchTask)
        if not M.run_task(launch.preLaunchTask) then
          return
        end
      end
      run_after_prelaunch()
    end)
  end)
end

function M.pick_launch()
  local launches = M.load_launches(M.find_task_root())
  if #launches == 0 then
    notify("No VS Code launch configurations found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(launches, {
    prompt = "Debug launch",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if choice and choice.name then
      M.run_launch(choice.name)
    end
  end)
end

function M.cleanup()
  local dap = require("dap")
  local ok_dapui, dapui = pcall(require, "dapui")

  if dap.session() ~= nil then
    pcall(dap.terminate)
    pcall(dap.disconnect)
  end

  if ok_dapui then
    pcall(dapui.close)
  end
  pcall(dap.repl.close)

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      local name = vim.api.nvim_buf_get_name(buf)
      if ft:match("^dap") or name:match("dap%-repl") or name:match("DAP ") then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local ft = vim.bo[buf].filetype
      local name = vim.api.nvim_buf_get_name(buf)
      if ft:match("^dap") or name:match("dap%-repl") or name:match("DAP ") then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
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

  vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#fb4934", bold = true })
  vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#fabd2f", bold = true })
  vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#83a598", bold = true })
  vim.api.nvim_set_hl(0, "DapStopped", { fg = "#b8bb26", bold = true })
  vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  vim.fn.sign_define("DapBreakpointCondition", { text = "C", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
  vim.fn.sign_define("DapLogPoint", { text = "L", texthl = "DapLogPoint", linehl = "", numhl = "" })
  vim.fn.sign_define("DapStopped", { text = ">", texthl = "DapStopped", linehl = "", numhl = "" })

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

  local function continue_or_pick_launch()
    if dap.session() ~= nil then
      dap.continue()
      return
    end
    M.pick_launch()
  end

  local map = vim.keymap.set
  map("n", "<F5>", continue_or_pick_launch, { desc = "Debug launch picker / continue" })
  map("n", "<F9>", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<F10>", dap.step_over, { desc = "Step over" })
  map("n", "<F11>", dap.step_into, { desc = "Step into" })
  map("n", "<S-F11>", dap.step_out, { desc = "Step out" })
  map("n", "<leader>dc", dap.continue, { desc = "Debug continue" })
  map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug breakpoint" })
  map("n", "<leader>dl", M.pick_launch, { desc = "Debug launch picker" })
  map("n", "<leader>dq", M.cleanup, { desc = "Debug stop and cleanup" })
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
