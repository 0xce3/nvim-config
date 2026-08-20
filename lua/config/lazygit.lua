local M = {}
local config_file
local window = { buf = nil, job = nil }

local function resize_window()
  if not window.buf or not window.job or vim.api.nvim_get_current_buf() ~= window.buf then return end

  local win = vim.api.nvim_get_current_win()
  pcall(vim.fn.jobresize, window.job, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
  local ok, pid = pcall(vim.fn.jobpid, window.job)
  if ok and pid > 0 then pcall(vim.uv.kill, pid, "sigwinch") end
end

local function with_config(opts, args)
  if not config_file then
    config_file = vim.fn.tempname() .. ".yml"
    local ok, err = pcall(vim.fn.writefile, {}, config_file)
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "lazygit" })
      config_file = nil
    end
  end

  opts = vim.deepcopy(opts or {})
  opts.args = vim.list_extend(config_file and { "-ucf", config_file } or {}, opts.args or args or {})
  return opts
end

function M.open(opts)
  return require("snacks").lazygit.open(with_config(opts))
end

function M.log(opts)
  return require("snacks").lazygit.open(with_config(opts, { "log" }))
end

function M.open_window()
  if window.buf and vim.api.nvim_buf_is_valid(window.buf) then
    local wins = vim.fn.win_findbuf(window.buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.api.nvim_set_current_buf(window.buf)
    end
    if window.job then vim.cmd("startinsert") end
    return
  end

  local opts = with_config()
  local cmd = vim.list_extend({ "lazygit" }, opts.args)

  window.buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(window.buf)
  vim.bo[window.buf].bufhidden = "hide"

  window.job = vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      window.job = nil
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify("Lazygit exited with code " .. exit_code, vim.log.levels.ERROR, { title = "lazygit" })
        end)
        return
      end
      vim.schedule(function()
        local buf = window.buf
        window.buf = nil
        if buf and vim.api.nvim_buf_is_valid(buf) then require("astrocore.buffer").close(buf, true) end
      end)
    end,
  })
  vim.api.nvim_buf_set_name(window.buf, "Lazygit")
  vim.bo[window.buf].filetype = "lazygit"
  vim.keymap.set("t", "<Esc>", function()
    if window.job then vim.api.nvim_chan_send(window.job, "\27") end
  end, {
    buffer = window.buf,
    silent = true,
    nowait = true,
    desc = "Send Escape to LazyGit",
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = window.buf,
    callback = function() vim.schedule(resize_window) end,
    desc = "Resize the LazyGit terminal after restoring its buffer",
  })
  resize_window()
  vim.cmd("startinsert")
end

return M
