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

return M
