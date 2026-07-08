local M = {}

local names = { "openapi.yaml", "openapi.yml", "swagger.yaml", "swagger.yml" }

local function path_join(...)
  local path = table.concat({ ... }, "/"):gsub("//+", "/")
  return path
end

local function project_root()
  local cwd = vim.uv.cwd()
  local found = vim.fs.find({ ".git" }, { upward = true, path = cwd })[1]
  return found and vim.fs.dirname(found) or cwd
end

local function hash_path(path)
  return vim.fn.sha256(vim.fn.fnamemodify(path, ":p")):sub(1, 16)
end

local function workspace_dir(root)
  local container_workspace = vim.env.NVIM_DEV_CONTAINER_WORKSPACE
  if vim.env.DEVCONTAINER == "true" and container_workspace and root:find(container_workspace .. "/", 1, true) == 1 then
    local parent = vim.fs.dirname(container_workspace)
    return path_join(parent, ".nvim-http-workspaces", hash_path(root))
  end
  return path_join(vim.fn.stdpath("state"), "http-workspaces", hash_path(root))
end

local function ensure_outside_repo(root, dir)
  local normalized_root = vim.fn.fnamemodify(root, ":p")
  local normalized_dir = vim.fn.fnamemodify(dir, ":p")
  if normalized_dir:find(normalized_root, 1, true) == 1 then
    error("Refusing to write HTTP workspace inside project repo: " .. normalized_dir)
  end
end

local function find_openapi(root)
  local found = vim.fs.find(names, { path = root, type = "file", limit = 20 })
  table.sort(found)
  return found[1]
end

local function sanitize_workspace_name(name)
  name = vim.trim(name or "")
  if name == "" then
    return nil
  end
  name = name:gsub("%.http$", "")
  name = name:gsub("[^A-Za-z0-9_.-]+", "-")
  name = name:gsub("%-+", "-")
  name = name:gsub("^%-", ""):gsub("%-$", "")
  if name == "" then
    return nil
  end
  return name
end

local function output_file(root, name)
  local dir = workspace_dir(root)
  ensure_outside_repo(root, dir)
  return path_join(dir, name .. ".http")
end

local function workspace_files(root)
  local dir = workspace_dir(root)
  ensure_outside_repo(root, dir)
  if vim.fn.isdirectory(dir) ~= 1 then
    return {}
  end

  local files = {}
  for entry, type_ in vim.fs.dir(dir) do
    if type_ == "file" and entry:match("%.http$") then
      table.insert(files, path_join(dir, entry))
    end
  end
  table.sort(files)
  return files
end

local function generator()
  return vim.fn.fnamemodify(vim.fn.stdpath("config") .. "/bin/openapi-to-http", ":p")
end

local function pick(items, opts, callback)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(items, opts, callback)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers.new({}, {
    prompt_title = opts.prompt or "Select",
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        local display = opts.format_item and opts.format_item(item) or tostring(item)
        return {
          value = item,
          display = display,
          ordinal = display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        callback(selection and selection.value or nil)
      end)
      return true
    end,
  }):find()
end

local function generate_to(openapi, workspace_name)
  local root = project_root()
  openapi = openapi or find_openapi(root)
  if not openapi then
    vim.notify("No openapi.yaml/openapi.yml/swagger.yaml/swagger.yml found", vim.log.levels.WARN)
    return
  end

  local safe_name = sanitize_workspace_name(workspace_name)
  if not safe_name then
    vim.notify("HTTP workspace generation cancelled", vim.log.levels.INFO)
    return
  end

  local out = output_file(root, safe_name)
  local result = vim.system({ generator(), openapi, out }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify(result.stderr ~= "" and result.stderr or "OpenAPI HTTP generation failed", vim.log.levels.ERROR)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(out))
  vim.notify("Generated HTTP workspace: " .. out, vim.log.levels.INFO)
end

function M.generate(openapi, workspace_name)
  if workspace_name then
    generate_to(openapi, workspace_name)
    return
  end

  vim.ui.input({ prompt = "HTTP workspace name: ", default = "requests" }, function(input)
    generate_to(openapi, input)
  end)
end

function M.open()
  local root = project_root()
  local files = workspace_files(root)
  if #files == 0 then
    vim.notify("No HTTP workspaces found; generating one", vim.log.levels.INFO)
    M.generate()
    return
  end

  table.insert(files, 1, "__new__")

  pick(files, {
    prompt = "HTTP workspace",
    format_item = function(item)
      if item == "__new__" then
        return "Create new workspace"
      end
      return vim.fn.fnamemodify(item, ":t")
    end,
  }, function(choice)
    if choice == "__new__" then
      M.generate()
    elseif choice then
      vim.cmd.edit(vim.fn.fnameescape(choice))
    end
  end)
end

function M.delete()
  local root = project_root()
  local files = workspace_files(root)
  if #files == 0 then
    vim.notify("No HTTP workspaces found", vim.log.levels.INFO)
    return
  end

  pick(files, {
    prompt = "Delete HTTP workspace",
    format_item = function(item)
      return vim.fn.fnamemodify(item, ":t")
    end,
  }, function(choice)
    if not choice then
      return
    end

    local label = vim.fn.fnamemodify(choice, ":t")
    vim.ui.select({ "Delete", "Cancel" }, { prompt = "Delete " .. label .. "?" }, function(confirm)
      if confirm ~= "Delete" then
        return
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == choice then
          vim.api.nvim_buf_delete(buf, { force = true })
          break
        end
      end

      local ok, err = os.remove(choice)
      if not ok then
        vim.notify("Failed to delete HTTP workspace: " .. tostring(err), vim.log.levels.ERROR)
        return
      end
      vim.notify("Deleted HTTP workspace: " .. label, vim.log.levels.INFO)
    end)
  end)
end

function M.pick_openapi()
  local root = project_root()
  local found = vim.fs.find(names, { path = root, type = "file", limit = 100 })
  if #found == 0 then
    vim.notify("No OpenAPI file found", vim.log.levels.WARN)
    return
  end
  pick(found, { prompt = "OpenAPI file" }, function(choice)
    if choice then
      M.generate(choice)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("HttpWorkspaceGenerate", function(opts)
    M.generate(nil, opts.args ~= "" and opts.args or nil)
  end, { desc = "Generate external .http workspace from OpenAPI", nargs = "?" })
  vim.api.nvim_create_user_command("HttpWorkspaceOpen", function()
    M.open()
  end, { desc = "Open external .http workspace" })
  vim.api.nvim_create_user_command("HttpWorkspaceDelete", function()
    M.delete()
  end, { desc = "Delete external .http workspace" })
  vim.api.nvim_create_user_command("HttpWorkspacePickOpenApi", function()
    M.pick_openapi()
  end, { desc = "Pick OpenAPI file and generate .http workspace" })
end

return M
