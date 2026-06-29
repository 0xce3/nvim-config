-- A single reusable terminal buffer for project tasks and quick shell access.
--
-- The terminal is a normal listed buffer. F12 switches the current window to it
-- (or back to the previous buffer); tasks reuse the same terminal job.

local M = {}

local state = {
  buf = nil,
  chan = nil,
  previous_buf = nil,
}

local function buf_ok()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function capture()
  state.buf = vim.api.nvim_get_current_buf()
  state.chan = vim.b[state.buf].terminal_job_id
  vim.bo[state.buf].buflisted = true
  vim.bo[state.buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(state.buf, "Task Terminal")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    once = true,
    callback = function()
      state.buf, state.chan = nil, nil
    end,
  })
end

local function open()
  if buf_ok() then
    vim.api.nvim_set_current_buf(state.buf)
  else
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

function M.run(command)
  if not command or command == "" then
    return
  end

  local fresh = not buf_ok()
  local current = vim.api.nvim_get_current_buf()
  if not (buf_ok() and current == state.buf) then
    state.previous_buf = current
  end
  open()

  local function send()
    if state.chan then
      vim.fn.chansend(state.chan, command .. "\n")
    end
  end

  if fresh then
    vim.defer_fn(send, 150)
  else
    send()
  end
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
