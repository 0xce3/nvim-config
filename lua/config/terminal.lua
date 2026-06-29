-- A single reusable terminal that lives in its own tab page.
--
-- Used for running project tasks and as a quick shell (F12). Exactly ONE
-- terminal tab is kept and re-used (tracked by tab + buffer handle) instead of
-- spawning a new terminal/tab per run. Typing `exit` (or <leader>tq) closes it.

local M = {}

local state = {
  buf = nil, -- terminal buffer id
  chan = nil, -- terminal job channel
  tab = nil, -- dedicated tab page handle
  prev_tab = nil, -- tab to jump back to on toggle
}

local function buf_ok()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function tab_ok()
  return state.tab ~= nil and vim.api.nvim_tabpage_is_valid(state.tab)
end

-- Turn the current window's buffer (just created via :terminal) into the
-- tracked terminal, and auto-close the tab when the shell exits.
local function capture()
  state.buf = vim.api.nvim_get_current_buf()
  state.chan = vim.b[state.buf].terminal_job_id
  vim.bo[state.buf].buflisted = false
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    once = true,
    callback = function()
      local tab = state.tab
      state.buf, state.chan, state.tab = nil, nil, nil
      vim.schedule(function()
        if tab and vim.api.nvim_tabpage_is_valid(tab) and #vim.api.nvim_list_tabpages() > 1 then
          pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(tab))
        end
      end)
    end,
  })
end

-- Focus the window showing the terminal buffer inside the tracked tab.
local function focus_term_win()
  if not (tab_ok() and buf_ok()) then
    return false
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(state.tab)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == state.buf then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end
  return false
end

-- Open/focus the single terminal tab, creating it (or its terminal) as needed.
local function open()
  if tab_ok() then
    vim.api.nvim_set_current_tabpage(state.tab)
    if buf_ok() then
      if not focus_term_win() then
        vim.api.nvim_set_current_buf(state.buf)
      end
    else
      vim.cmd("terminal")
      capture()
    end
  else
    vim.cmd("$tabnew")
    state.tab = vim.api.nvim_get_current_tabpage()
    if buf_ok() then
      vim.api.nvim_set_current_buf(state.buf)
    else
      vim.cmd("terminal")
      capture()
    end
  end
  vim.cmd("startinsert")
end

-- F12: open/focus the terminal tab, or jump back if already on it.
function M.toggle()
  if tab_ok() and vim.api.nvim_get_current_tabpage() == state.tab then
    if state.prev_tab and vim.api.nvim_tabpage_is_valid(state.prev_tab) then
      vim.api.nvim_set_current_tabpage(state.prev_tab)
    else
      pcall(vim.cmd, "tabprevious")
    end
    return
  end
  state.prev_tab = vim.api.nvim_get_current_tabpage()
  open()
end

-- Run a shell command in the reusable terminal (creates + focuses it).
function M.run(command)
  if not command or command == "" then
    return
  end
  local fresh = not buf_ok()
  state.prev_tab = vim.api.nvim_get_current_tabpage()
  open()
  local function send()
    if state.chan then
      vim.fn.chansend(state.chan, command .. "\n")
    end
  end
  if fresh then
    vim.defer_fn(send, 150) -- let the freshly started shell come up
  else
    send()
  end
end

-- Close the terminal tab and kill its shell.
function M.close()
  if tab_ok() and #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(state.tab))
  end
  if state.chan then
    pcall(vim.fn.jobstop, state.chan)
  end
  if buf_ok() then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.buf, state.chan, state.tab = nil, nil, nil
end

return M
