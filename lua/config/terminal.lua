-- A single reusable terminal buffer for project tasks and quick shell access.
--
-- The terminal is shown in a normal split, not a tabpage. F12 toggles the split;
-- tasks reuse the same terminal job and send commands to it.

local M = {}

local state = {
  buf = nil,
  chan = nil,
  win = nil,
  previous_win = nil,
}

local function buf_ok()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_ok()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function find_window()
  if not buf_ok() then
    return nil
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == state.buf then
      return win
    end
  end
  return nil
end

local function capture()
  state.buf = vim.api.nvim_get_current_buf()
  state.win = vim.api.nvim_get_current_win()
  state.chan = vim.b[state.buf].terminal_job_id
  vim.bo[state.buf].buflisted = true
  vim.bo[state.buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(state.buf, "Task Terminal")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    once = true,
    callback = function()
      state.buf, state.chan, state.win = nil, nil, nil
    end,
  })
end

local function create_split()
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, math.max(12, math.floor(vim.o.lines * 0.30)))
  if buf_ok() then
    vim.api.nvim_win_set_buf(0, state.buf)
    state.win = vim.api.nvim_get_current_win()
  else
    vim.cmd("terminal")
    capture()
  end
end

local function open()
  local existing = find_window()
  if existing then
    state.win = existing
    vim.api.nvim_set_current_win(existing)
  else
    create_split()
  end
  vim.cmd("startinsert")
end

function M.toggle()
  local current = vim.api.nvim_get_current_win()
  local existing = find_window()

  if existing and current == existing then
    if state.previous_win and vim.api.nvim_win_is_valid(state.previous_win) then
      vim.api.nvim_set_current_win(state.previous_win)
    else
      pcall(vim.cmd, "wincmd p")
    end
    return
  end

  if existing then
    state.previous_win = current
    state.win = existing
    vim.api.nvim_set_current_win(existing)
    vim.cmd("startinsert")
    return
  end

  state.previous_win = current
  open()
end

function M.run(command)
  if not command or command == "" then
    return
  end

  local fresh = not buf_ok()
  if not win_ok() then
    state.previous_win = vim.api.nvim_get_current_win()
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
  local win = find_window()
  if win then
    pcall(vim.api.nvim_win_close, win, true)
  end
  state.win = nil
end

function M.kill()
  if state.chan then
    pcall(vim.fn.jobstop, state.chan)
  end
  if buf_ok() then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.buf, state.chan, state.win = nil, nil, nil
end

return M
