local M = {}

local function ensure_config_file()
  local config_dir = vim.fn.systemlist({ "lazygit", "-cd" })[1]
  if vim.v.shell_error ~= 0 or not config_dir or config_dir == "" then return end

  local config_file = vim.fs.joinpath(config_dir, "config.yml")
  if vim.uv.fs_stat(config_file) then return end

  local ok, err = pcall(vim.fn.mkdir, config_dir, "p")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "lazygit" })
    return
  end

  ok, err = pcall(vim.fn.writefile, {}, config_file)
  if not ok then vim.notify(err, vim.log.levels.ERROR, { title = "lazygit" }) end
end

function M.open(opts)
  ensure_config_file()
  return require("snacks").lazygit.open(opts)
end

function M.log(opts)
  ensure_config_file()
  return require("snacks").lazygit.log(opts)
end

return M
