local M = {}

function M.current_file_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN, { title = "path" })
    return nil
  end
  return vim.fn.fnamemodify(path, ":p")
end

function M.copy_path(path)
  if not path or path == "" then return false end
  vim.fn.setreg('"', path)
  vim.fn.setreg("+", path)
  vim.notify("Copied path: " .. path, vim.log.levels.INFO, { title = "path" })
  return true
end

function M.copy_current_file_path()
  return M.copy_path(M.current_file_path())
end

function M.open_terminal(path)
  local file_path = M.current_file_path()
  local cwd = path and path ~= "." and vim.fn.fnamemodify(vim.fn.expand(path), ":p")
    or (file_path and vim.fn.fnamemodify(file_path, ":h"))
    or vim.fn.getcwd()
  if vim.fn.isdirectory(cwd) ~= 1 then
    vim.notify("Not a directory: " .. cwd, vim.log.levels.ERROR, { title = "terminal" })
    return
  end
  vim.cmd("enew!")
  vim.fn.termopen(vim.o.shell, { cwd = cwd })
  vim.cmd("startinsert")
end

return M
