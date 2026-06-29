local M = {}

local state = {
  connected = false,
  container_id = nil,
  container_name = nil,
  project_path = nil,
  workspace_folder = nil,
}

function M.setup()
  local group = vim.api.nvim_create_augroup("DevcontainerHub", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ContainerOpened",
    group = group,
    callback = function(ev)
      state.connected = true
      state.container_name = ev.data and ev.data.container_name
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ContainerStarted",
    group = group,
    callback = function(ev)
      state.connected = true
      state.container_id = require("container").get_container_id()
      local info = require("config.container_detect").get_container_workspace_folder(state.container_id)
      if info then
        state.workspace_folder = info
      end
      pcall(function() require("lualine").refresh({ place = { "statusline" } }) end)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ContainerStopped",
    group = group,
    callback = function()
      M.reset()
      pcall(function() require("lualine").refresh({ place = { "statusline" } }) end)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ContainerClosed",
    group = group,
    callback = function()
      M.reset()
      pcall(function() require("lualine").refresh({ place = { "statusline" } }) end)
    end,
  })
end

function M.reset()
  state.connected = false
  state.container_id = nil
  state.container_name = nil
  state.project_path = nil
  state.workspace_folder = nil
end

function M.is_connected()
  return state.connected
end

function M.info()
  if not state.connected then
    return nil
  end
  return {
    container_id = state.container_id,
    container_name = state.container_name,
    project_path = state.project_path,
    workspace_folder = state.workspace_folder,
  }
end

function M.statusline()
  if not state.connected then
    return ""
  end
  return " " .. (state.container_name or state.container_id or "devcontainer")
end

function M.open(project_path)
  project_path = project_path or vim.fn.getcwd()
  state.project_path = project_path

  local container = require("container")
  local ok = container.open(project_path)
  if not ok then
    vim.notify("Failed to open devcontainer config at " .. project_path, vim.log.levels.ERROR)
    return
  end

  vim.notify("Building devcontainer image...", vim.log.levels.INFO, { title = "Devcontainer" })
  vim.defer_fn(function()
    container.build()
  end, 100)

  vim.defer_fn(function()
    container.start()
  end, 500)
end

function M.rebuild(project_path)
  project_path = project_path or vim.fn.getcwd()
  state.project_path = project_path
  require("container").rebuild(project_path)
end

function M.stop()
  require("container").stop()
end

function M.kill()
  require("container").kill()
end

function M.restart()
  require("container").restart()
end

function M.shell()
  require("container").terminal()
end

function M.connect(opts)
  opts = opts or {}
  local container_detect = require("config.container_detect")
  local containers = container_detect.list_running_containers()

  if #containers == 0 then
    vim.notify("No running containers found", vim.log.levels.WARN)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values

  local entries = {}
  for _, c in ipairs(containers) do
    local ws = c.workspace_folder ~= "" and "  " .. c.workspace_folder or ""
    table.insert(entries, {
      display = "   " .. c.name .. ws,
      ordinal = c.name .. " " .. c.project,
      id = c.id,
      name = c.name,
      workspace_folder = c.workspace_folder,
    })
  end

  pickers
    .new({}, {
      prompt_title = "Connect to Container",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return { value = entry, display = entry.display, ordinal = entry.ordinal }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection then return end
          M._attach_to(selection.value)
        end)
        return true
      end,
    })
    :find()
end

function M._attach_to(entry)
  state.container_name = entry.name

  if entry.workspace_folder ~= "" and vim.fn.isdirectory(entry.workspace_folder) == 1 then
    state.workspace_folder = entry.workspace_folder
    state.project_path = entry.workspace_folder
    vim.api.nvim_set_current_dir(entry.workspace_folder)
    vim.notify("Attached to " .. entry.name .. " at " .. entry.workspace_folder, vim.log.levels.INFO)
  else
    vim.notify("Attached to " .. entry.name, vim.log.levels.INFO)
  end

  require("container").attach(entry.name)
  state.connected = true
  state.container_id = entry.id
end

function M.find_project_root()
  local cwd = vim.uv.cwd()
  local matches = vim.fs.find({ ".devcontainer", ".git", ".vscode" }, { upward = true, path = cwd })
  if #matches == 0 then
    return cwd
  end
  return vim.fs.dirname(matches[1])
end

function M.has_devcontainer(path)
  path = path or vim.uv.cwd()
  return vim.fn.filereadable(path .. "/.devcontainer/devcontainer.json") == 1
    or vim.fn.filereadable(path .. "/devcontainer.json") == 1
end

function M.reopen(path)
  path = path or M.find_project_root()

  if not M.has_devcontainer(path) then
    vim.notify("No devcontainer.json found at " .. path, vim.log.levels.WARN)
    return
  end

  local container_detect = require("config.container_detect")
  local containers = container_detect.list_running_containers()

  local already_running = false
  for _, c in ipairs(containers) do
    if c.workspace_folder == path then
      already_running = true
      vim.notify("Container already running for " .. path .. ", attaching...", vim.log.levels.INFO)
      M._attach_to(c)
      return
    end
  end

  M.open(path)
end

return M
