local M = {}
local config_file

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

function M.open_split()
  local opts = with_config()
  local cmd = vim.list_extend({ "lazygit" }, opts.args)

  vim.cmd("botright 15new")
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, "Lazygit")
  vim.bo[buf].bufhidden = "wipe"

  vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify("Lazygit exited with code " .. exit_code, vim.log.levels.ERROR, { title = "lazygit" })
        end)
        return
      end
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      end)
    end,
  })
  vim.cmd("startinsert")
end

return M
