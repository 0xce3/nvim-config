local M = {}

function M.is_win_supported(_, bufnr)
  return require("config.terminal").is_terminal_buffer(bufnr)
end

function M.save_win()
  return {}
end

function M.load_win(winid)
  vim.api.nvim_set_current_win(winid)
  require("config.terminal").restore()
  return winid
end

return M
