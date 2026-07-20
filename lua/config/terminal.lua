-- A single reusable terminal buffer for project tasks and quick shell access.
--
-- The terminal is a normal listed buffer. F12 switches the current window to it
-- (or back to the previous buffer); tasks reuse the same terminal job.

local M = {}

local state = {
  buf = nil,
  chan = nil,
  previous_buf = nil,
  task_running = false,
  task_status = nil,
  task_label = nil,
  spinner = 1,
  marker = nil,
}

local debug_state = { buf = nil, chan = nil, previous_buf = nil }

local function redraw_spinner()
  if not state.task_running then return end
  vim.cmd("redrawstatus")
  vim.defer_fn(redraw_spinner, 120)
end

local function mark_task_complete()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)) do
    local exit_code = state.marker and line:match(vim.pesc(state.marker) .. ":(%d+)")
    if exit_code then
      exit_code = tonumber(exit_code)
      state.task_running = false
      state.marker = nil
      state.task_status = exit_code == 0 and "success" or "failed"
      vim.cmd("redrawstatus")
      if exit_code == 0 then
        vim.notify("Task completed successfully", vim.log.levels.INFO, { title = "Task Terminal" })
      else
        vim.notify("Task failed with exit code " .. exit_code, vim.log.levels.ERROR, { title = "Task Terminal" })
      end
      return
    end
  end
end

local function buf_ok()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

function M.is_terminal_buffer(bufnr)
  return buf_ok() and bufnr == state.buf
end

function M.is_task_running()
  return state.task_running
end

function M.task_status()
  return state.task_status
end

function M.task_label()
  return state.task_label
end

function M.task_spinner()
  local ok, astroui = pcall(require, "astroui")
  if not ok then return "..." end
  local frames = astroui.get_spinner("LSPLoading", 1) or { "..." }
  return frames[math.floor(vim.uv.hrtime() / 120000000) % #frames + 1]
end

local function capture()
  state.buf = vim.api.nvim_get_current_buf()
  state.chan = vim.b[state.buf].terminal_job_id
  vim.bo[state.buf].buflisted = true
  vim.bo[state.buf].bufhidden = "hide"

  local existing = vim.fn.bufnr("Task Terminal")
  if existing ~= -1 and existing ~= state.buf then
    pcall(vim.api.nvim_buf_delete, existing, { force = true })
  end
  vim.api.nvim_buf_set_name(state.buf, "Task Terminal")
  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
    buffer = state.buf,
    silent = true,
    desc = "Leave task terminal mode",
  })
  vim.api.nvim_buf_attach(state.buf, false, { on_lines = mark_task_complete })

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    once = true,
    callback = function()
      state.buf, state.chan, state.task_running = nil, nil, false
    end,
  })
end

local function open()
  if buf_ok() then
    vim.api.nvim_set_current_buf(state.buf)
  else
    -- Telescope's prompt buffer is modified while a task is selected, and
    -- :terminal cannot replace a modified buffer. Use a scratch buffer first
    -- so special buffers such as Neo-tree remain untouched.
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(scratch)
    vim.cmd("terminal")
    capture()
  end
  vim.cmd("startinsert")
end

function M.toggle()
  local current = vim.api.nvim_get_current_buf()

  if buf_ok() and current == state.buf then
    if state.previous_buf and vim.api.nvim_buf_is_valid(state.previous_buf) then
      vim.api.nvim_set_current_buf(state.previous_buf)
    else
      pcall(vim.cmd, "buffer #")
    end
    return
  end

  state.previous_buf = current
  open()
end

function M.run(command, label)
  if not command or command == "" then
    return
  end

  local fresh = not buf_ok()
  local current = vim.api.nvim_get_current_buf()
  if not (buf_ok() and current == state.buf) then
    state.previous_buf = current
  end

  if fresh then
    -- Create the reusable terminal in the current window, then immediately
    -- restore the user's buffer. Tasks remain visible through F12/<leader>tj.
    open()
    if vim.api.nvim_buf_is_valid(current) then
      vim.api.nvim_set_current_buf(current)
      vim.cmd("stopinsert")
    end
  end

  local function send()
    if state.chan then
      state.task_running = true
      state.task_status = nil
      state.task_label = label or "Task"
      state.spinner = 1
      state.marker = "__NVIM_TASK_DONE_" .. tostring(vim.loop.hrtime()) .. "__"
      vim.cmd("redrawstatus")
      redraw_spinner()
      vim.fn.chansend(
        state.chan,
        "{ " .. command .. "; }; task_exit=$?; printf '\\n" .. state.marker .. ":%s\\n' \"$task_exit\"\n"
      )
    end
  end

  if fresh then
    vim.defer_fn(send, 150)
  else
    send()
  end
end

function M.run_debug(command)
  if not command or command == "" then return end
  if debug_state.buf and vim.api.nvim_buf_is_valid(debug_state.buf) then
    vim.api.nvim_set_current_buf(debug_state.buf)
    vim.fn.chansend(debug_state.chan, command .. "\n")
    vim.cmd("startinsert")
    return
  end

  debug_state.previous_buf = vim.api.nvim_get_current_buf()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(scratch)
  vim.cmd("terminal")
  debug_state.buf = vim.api.nvim_get_current_buf()
  debug_state.chan = vim.b[debug_state.buf].terminal_job_id
  vim.bo[debug_state.buf].buflisted = true
  vim.bo[debug_state.buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(debug_state.buf, "Debug Terminal")
  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
    buffer = debug_state.buf,
    silent = true,
    desc = "Leave debug terminal mode",
  })
  vim.keymap.set("t", "<C-c>", function() M.stop_debug_session() end, {
    buffer = debug_state.buf,
    silent = true,
    desc = "Stop debug session",
  })
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = debug_state.buf,
    once = true,
    callback = function()
      debug_state.buf, debug_state.chan = nil, nil
      vim.schedule(function()
        local dap = require("dap")
        if dap.session() then pcall(dap.terminate) end
      end)
    end,
  })
  vim.defer_fn(function()
    if debug_state.chan then vim.fn.chansend(debug_state.chan, command .. "\n") end
  end, 150)
  vim.defer_fn(function()
    if debug_state.buf and vim.api.nvim_buf_is_valid(debug_state.buf) then
      vim.api.nvim_set_current_buf(debug_state.buf)
      vim.cmd("startinsert")
    end
  end, 500)
end

function M.toggle_debug()
  if not debug_state.buf or not vim.api.nvim_buf_is_valid(debug_state.buf) then
    vim.notify("Debug terminal is not running", vim.log.levels.WARN, { title = "debug" })
    return
  end
  local current = vim.api.nvim_get_current_buf()
  if current == debug_state.buf then
    if debug_state.previous_buf and vim.api.nvim_buf_is_valid(debug_state.previous_buf) then
      vim.api.nvim_set_current_buf(debug_state.previous_buf)
    end
  else
    debug_state.previous_buf = current
    vim.api.nvim_set_current_buf(debug_state.buf)
    vim.cmd("startinsert")
  end
end

function M.stop_debug()
  if debug_state.chan then vim.fn.chansend(debug_state.chan, "\003") end
end

function M.stop_debug_session()
  M.stop_debug()
  local dap = require("dap")
  if dap.session() then pcall(dap.terminate) end
end

function M.send(keys)
  if not state.chan then
    vim.notify("Task terminal is not running", vim.log.levels.WARN, { title = "terminal" })
    return false
  end
  vim.fn.chansend(state.chan, vim.api.nvim_replace_termcodes(keys, true, false, true))
  return true
end

function M.stop_task()
  if not state.chan or not state.task_running then return end
  vim.fn.chansend(state.chan, "\003")
  state.task_running = false
  state.task_status = "failed"
  state.marker = nil
  vim.cmd("redrawstatus")
end

function M.tmux(command)
  return M.send("<C-b>" .. command)
end

function M.close()
  if buf_ok() and vim.api.nvim_get_current_buf() == state.buf then
    if state.previous_buf and vim.api.nvim_buf_is_valid(state.previous_buf) then
      vim.api.nvim_set_current_buf(state.previous_buf)
    else
      pcall(vim.cmd, "buffer #")
    end
  end
end

function M.kill()
  if state.chan then
    pcall(vim.fn.jobstop, state.chan)
  end
  if buf_ok() then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.buf, state.chan = nil, nil
end

return M
