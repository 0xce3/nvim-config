local M = {}
local state = { buf = nil, job = nil, cwd = nil, cwd_file = nil, chooser_file = nil }

local function resize_window()
  if not state.buf or not state.job or vim.api.nvim_get_current_buf() ~= state.buf then return end

  local win = vim.api.nvim_get_current_win()
  pcall(vim.fn.jobresize, state.job, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
  local ok, pid = pcall(vim.fn.jobpid, state.job)
  if ok and pid > 0 then pcall(vim.uv.kill, pid, "sigwinch") end
end

local function read_first_line(path)
  if not path or vim.fn.filereadable(path) ~= 1 then return nil end
  local lines = vim.fn.readfile(path)
  return lines[1]
end

local function finish(exit_code)
  state.job = nil
  state.cwd = read_first_line(state.cwd_file) or state.cwd
  local choices = state.chooser_file and vim.fn.filereadable(state.chooser_file) == 1
      and vim.fn.readfile(state.chooser_file)
    or {}
  local buf = state.buf
  state.buf = nil

  if exit_code ~= 0 then
    state.buf = buf
    vim.notify("Yazi exited with code " .. exit_code, vim.log.levels.ERROR, { title = "yazi" })
    return
  end

  local wins = buf and vim.api.nvim_buf_is_valid(buf) and vim.fn.win_findbuf(buf) or {}
  if choices[1] and choices[1] ~= "" then
    local target = vim.fn.bufadd(choices[1])
    vim.fn.bufload(target)
    if wins[1] and vim.api.nvim_win_is_valid(wins[1]) then vim.api.nvim_win_set_buf(wins[1], target) end
    for index = 2, #choices do
      if choices[index] ~= "" then vim.fn.bufadd(choices[index]) end
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  elseif buf and vim.api.nvim_buf_is_valid(buf) then
    require("astrocore.buffer").close(buf, true)
  end
end

function M.open_window()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    local wins = vim.fn.win_findbuf(state.buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.api.nvim_set_current_buf(state.buf)
    end
    if state.job then vim.cmd("startinsert") end
    return
  end

  state.cwd_file = state.cwd_file or vim.fn.tempname()
  state.chooser_file = state.chooser_file or vim.fn.tempname()
  vim.fn.writefile({}, state.cwd_file)
  vim.fn.writefile({}, state.chooser_file)

  local entry = state.cwd
  if not entry then
    local current = vim.api.nvim_buf_get_name(0)
    entry = current ~= "" and vim.uv.fs_stat(current) and current or vim.uv.cwd()
  end

  state.buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(state.buf)
  vim.bo[state.buf].bufhidden = "hide"
  state.job = vim.fn.termopen({
    "yazi",
    "--cwd-file",
    state.cwd_file,
    "--chooser-file",
    state.chooser_file,
    entry,
  }, {
    on_exit = function(_, exit_code) vim.schedule(function() finish(exit_code) end) end,
  })
  vim.api.nvim_buf_set_name(state.buf, "Yazi")
  vim.bo[state.buf].filetype = "yazi"
  vim.keymap.set("t", "<Esc>", function()
    if state.job then vim.fn.chansend(state.job, "\27") end
  end, {
    buffer = state.buf,
    silent = true,
    desc = "Send Escape to Yazi",
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = state.buf,
    callback = function() vim.schedule(resize_window) end,
    desc = "Resize the Yazi terminal after restoring its buffer",
  })
  resize_window()
  vim.cmd("startinsert")
end

return M
