-- Persist the clangd build directory selected via <leader>fc, per project.
--
-- Stored in Neovim's state dir (NOT in the project), so switching builds never
-- creates generated files that could be committed accidentally.

local M = {}

local function state_file()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "clangd_build_dirs.json")
end

local function read_all()
  local fd = io.open(state_file(), "r")
  if not fd then
    return {}
  end
  local content = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, content or "")
  if ok and type(data) == "table" then
    return data
  end
  return {}
end

-- Saved build dir for a project root, or nil if none / no longer valid.
function M.get(project)
  local dir = read_all()[project]
  if dir and vim.fn.filereadable(dir .. "/compile_commands.json") == 1 then
    return dir
  end
  return nil
end

function M.set(project, dir)
  local all = read_all()
  all[project] = dir
  local fd = io.open(state_file(), "w")
  if fd then
    fd:write(vim.json.encode(all))
    fd:close()
  end
end

return M
