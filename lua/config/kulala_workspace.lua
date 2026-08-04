local M = {}

local function root()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "kulala", "workspaces")
end

local function ensure_root()
  vim.fn.mkdir(root(), "p")
end

local function workspace_names()
  ensure_root()
  local names = {}
  for name, type_ in vim.fs.dir(root()) do
    if type_ == "directory" then table.insert(names, name) end
  end
  table.sort(names)
  return names
end

local function open_request(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.open()
  local snacks = require("snacks")
  local items = vim.tbl_map(function(name) return { text = name, workspace = name } end, workspace_names())
  if #items == 0 then return M.new() end
  snacks.picker.pick({
    title = "Kulala Workspace",
    items = items,
    format = "text",
    confirm = function(picker, item)
      picker:close()
      M.open_requests(item.workspace)
    end,
  })
end

function M.open_requests(name)
  local path = vim.fs.joinpath(root(), name)
  require("snacks").picker.files({ cwd = path, title = "Kulala: " .. name })
end

function M.new()
  vim.ui.input({ prompt = "New Kulala workspace: " }, function(name)
    if not name or name == "" or name:match("[^%w_.%-]") then
      if name and name ~= "" then vim.notify("Invalid workspace name", vim.log.levels.ERROR, { title = "Kulala" }) end
      return
    end
    local path = vim.fs.joinpath(root(), name)
    if vim.fn.isdirectory(path) == 1 then
      vim.notify("Workspace already exists: " .. name, vim.log.levels.WARN, { title = "Kulala" })
      return
    end
    vim.fn.mkdir(path, "p")
    local request = vim.fs.joinpath(path, "requests.http")
    local file = io.open(request, "w")
    if file then
      file:write("### " .. name .. "\n\n")
      file:close()
    end
    open_request(request)
  end)
end

function M.pick_request()
  local names = workspace_names()
  if #names == 0 then return M.new() end
  vim.ui.select(names, { prompt = "Kulala workspace" }, function(name)
    if name then M.open_requests(name) end
  end)
end

return M
