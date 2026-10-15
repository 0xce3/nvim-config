local M = {}

local function executable(path)
  return type(path) == "string" and path ~= "" and vim.fn.executable(path) == 1
end

local function python_in(dir)
  for _, name in ipairs({ ".venv", "venv", "env", ".env" }) do
    local candidate = vim.fs.joinpath(dir, name, "bin", "python")
    if executable(candidate) then return candidate end
    candidate = vim.fs.joinpath(dir, name, "Scripts", "python.exe")
    if executable(candidate) then return candidate end
  end
end

function M.root(path)
  return vim.fs.root(path or 0, {
    "pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini", ".python-version", ".git",
  }) or vim.fn.getcwd()
end

function M.python(path)
  local root = M.root(path)
  local active = vim.env.VIRTUAL_ENV
  if active then
    local candidate = vim.fs.joinpath(active, "bin", "python")
    if executable(candidate) then return candidate end
    candidate = vim.fs.joinpath(active, "Scripts", "python.exe")
    if executable(candidate) then return candidate end
  end

  local project = python_in(root)
  if project then return project end

  -- pyenv's shim resolves the project-local .python-version automatically.
  local pyenv = vim.fn.exepath("pyenv")
  if pyenv ~= "" then
    local candidate = vim.fn.system({ pyenv, "which", "python" }):gsub("%s+$", "")
    if executable(candidate) then return candidate end
  end

  for _, name in ipairs({ "python3", "python" }) do
    local candidate = vim.fn.exepath(name)
    if executable(candidate) then return candidate end
  end
  return "python3"
end

function M.env(path)
  local python = M.python(path)
  return { python = python, cwd = M.root(path) }
end

return M
