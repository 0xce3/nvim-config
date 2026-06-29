local M = {}

local state = {
  docker_available = nil,
  running_containers = nil,
  devcontainer_projects = nil,
  cache_ready = false,
  cache_time = 0,
}

local CACHE_TTL_MS = 5000
local _refresh_pending = false

function M.is_cache_ready()
  return state.cache_ready
end

function M.invalidate_cache()
  state.docker_available = nil
  state.running_containers = nil
  state.devcontainer_projects = nil
  state.cache_ready = false
  state.cache_time = 0
end

function M.is_docker_available()
  if state.docker_available ~= nil then
    return state.docker_available
  end
  if vim.fn.executable("docker") == 0 then
    state.docker_available = false
    return false
  end
  local ok, result = pcall(vim.system, { "docker", "info", "--format", "{{.ServerVersion}}" }, { text = true, timeout = 3000 })
  state.docker_available = ok and result ~= nil and result.code == 0
  return state.docker_available
end

function M.list_running_containers()
  if not M.is_docker_available() then
    return {}
  end

  if state.running_containers ~= nil and (vim.loop.hrtime() / 1e6 - state.cache_time) < CACHE_TTL_MS then
    return state.running_containers
  end

  local ok_result, result = pcall(vim.system, { "docker", "ps", "--format", "{{json .}}" }, { text = true, timeout = 5000 })
  if not ok_result or result == nil or result.code ~= 0 or not result.stdout or result.stdout == "" then
    state.running_containers = {}
    state.cache_time = vim.loop.hrtime() / 1e6
    return {}
  end

  local containers = {}
  for _, line in ipairs(vim.split(result.stdout, "\n", { trimempty = true })) do
    local ok, data = pcall(vim.json.decode, line)
    if ok and data then
      local ok_inspect, inspect = pcall(vim.system,
        { "docker", "inspect", data.ID, "--format", "{{json .Config.Labels}}" },
        { text = true, timeout = 3000 })
      local labels = {}
      if ok_inspect and inspect ~= nil and inspect.code == 0 and inspect.stdout then
        local ok2, lbls = pcall(vim.json.decode, inspect.stdout)
        if ok2 then
          labels = lbls
        end
      end

      local workspace_folder = labels["devcontainer.local_folder"] or ""
      local config_file = labels["devcontainer.config_file"] or ""
      local project_name = ""

      if config_file ~= "" then
        project_name = vim.fn.fnamemodify(config_file, ":h:h:t")
      end
      if project_name == "" then
        project_name = data.Names:gsub("^/", "")
      end

      table.insert(containers, {
        id = data.ID:sub(1, 12),
        name = data.Names:gsub("^/", ""),
        image = data.Image,
        status = data.Status,
        project = project_name,
        workspace_folder = workspace_folder,
        config_file = config_file,
        created = data.CreatedAt,
      })
    end
  end

  state.running_containers = containers
  state.cache_time = vim.loop.hrtime() / 1e6
  return containers
end

function M.get_cached_containers()
  if not state.cache_ready then
    return nil
  end
  return state.running_containers or {}
end

function M.get_cached_devcontainer_projects()
  if not state.cache_ready then
    return nil
  end
  return state.devcontainer_projects or {}
end

-- Async background refresh using vim.system callback (does not block).
function M.refresh_cache_async(callback)
  if _refresh_pending then
    return
  end
  _refresh_pending = true

  -- First check docker availability (synchronous, fast because vim.fn.executable
  -- is instant for already-cached lookups).
  if vim.fn.executable("docker") == 0 then
    state.docker_available = false
    state.running_containers = {}
    state.devcontainer_projects = M._find_devcontainer_projects_sync()
    state.cache_ready = true
    _refresh_pending = false
    if callback then callback() end
    return
  end

  local cmd = vim.fn.executable("fd") == 1
    and { "fd", "devcontainer.json", vim.env.HOME, "--type", "f", "--max-depth", "5", "--hidden", "--no-ignore" }
    or { "find", vim.env.HOME, "-maxdepth", "5", "-type", "f", "-name", "devcontainer.json" }

  local containers_done = false
  local projects_done = false
  local function try_finish()
    if containers_done and projects_done then
      state.cache_ready = true
      _refresh_pending = false
      if callback then callback() end
    end
  end

  -- Docker ps (async callback)
  vim.system({ "docker", "ps", "--format", "{{json .}}" }, { text = true }, function(docker_result)
    local containers = {}
    if docker_result and docker_result.code == 0 and docker_result.stdout then
      for _, line in ipairs(vim.split(docker_result.stdout, "\n", { trimempty = true })) do
        local ok, data = pcall(vim.json.decode, line)
        if ok and data then
          table.insert(containers, {
            id = data.ID:sub(1, 12),
            name = data.Names:gsub("^/", ""),
            image = data.Image,
            status = data.Status,
            project = data.Names:gsub("^/", ""),
            workspace_folder = "",
            config_file = "",
            created = data.CreatedAt,
          })
        end
      end
    end

    -- Enrich with labels via separate inspect calls (still async)
    if #containers == 0 then
      state.running_containers = {}
      containers_done = true
      try_finish()
      return
    end

    local pending = #containers
    for _, c in ipairs(containers) do
      vim.system({ "docker", "inspect", c.id, "--format", "{{json .Config.Labels}}" }, { text = true }, function(inspect_result)
        if inspect_result and inspect_result.code == 0 and inspect_result.stdout then
          local ok, labels = pcall(vim.json.decode, inspect_result.stdout)
          if ok and labels then
            c.workspace_folder = labels["devcontainer.local_folder"] or ""
            c.config_file = labels["devcontainer.config_file"] or ""
            if c.config_file ~= "" then
              c.project = vim.fn.fnamemodify(c.config_file, ":h:h:t")
            end
          end
        end
        pending = pending - 1
        if pending == 0 then
          state.running_containers = containers
          containers_done = true
          try_finish()
        end
      end)
    end
  end)

  -- Devcontainer projects via fd/find (async callback)
  vim.system(cmd, { text = true }, function(output)
    local results = {}
    if output and output.code == 0 and output.stdout then
      local seen = {}
      for _, file in ipairs(vim.split(output.stdout, "\n", { trimempty = true })) do
        local project_dir = vim.fn.fnamemodify(file, ":h:h")
        local name = vim.fn.fnamemodify(project_dir, ":t")
        if not seen[project_dir] and vim.fn.isdirectory(project_dir) == 1 then
          seen[project_dir] = true
          table.insert(results, {
            name = name,
            path = project_dir,
            config_path = file,
          })
        end
      end
    end
    state.devcontainer_projects = results
    projects_done = true
    try_finish()
  end)
end

-- Synchronous fallback for devcontainer project search (only used when
-- docker is not available, which is fast).
function M._find_devcontainer_projects_sync()
  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = { "fd", "devcontainer.json", vim.env.HOME, "--type", "f", "--max-depth", "5", "--hidden", "--no-ignore" }
  elseif vim.fn.executable("find") == 1 then
    cmd = { "find", vim.env.HOME, "-maxdepth", "5", "-type", "f", "-name", "devcontainer.json" }
  else
    return {}
  end
  local ok_out, output = pcall(vim.system, cmd, { text = true, timeout = 10000 })
  if not ok_out or output == nil or output.code ~= 0 or not output.stdout then
    return {}
  end
  local results = {}
  local seen = {}
  for _, file in ipairs(vim.split(output.stdout, "\n", { trimempty = true })) do
    local project_dir = vim.fn.fnamemodify(file, ":h:h")
    local name = vim.fn.fnamemodify(project_dir, ":t")
    if not seen[project_dir] and vim.fn.isdirectory(project_dir) == 1 then
      seen[project_dir] = true
      table.insert(results, { name = name, path = project_dir, config_path = file })
    end
  end
  return results
end

function M.get_container_workspace_folder(container_id)
  if not M.is_docker_available() then
    return nil
  end
  local ok, result = pcall(vim.system,
    { "docker", "inspect", container_id, "--format", "{{index .Config.Labels \"devcontainer.local_folder\"}}" },
    { text = true, timeout = 3000 })
  if ok and result ~= nil and result.code == 0 and result.stdout then
    local folder = vim.trim(result.stdout)
    return folder ~= "" and folder or nil
  end
  return nil
end

function M.find_devcontainer_projects(search_base)
  search_base = search_base or vim.env.HOME
  if not search_base or vim.fn.isdirectory(search_base) == 0 then
    return {}
  end

  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = { "fd", "devcontainer.json", search_base, "--type", "f", "--max-depth", "5", "--hidden", "--no-ignore" }
  elseif vim.fn.executable("find") == 1 then
    cmd = { "find", search_base, "-maxdepth", "5", "-type", "f", "-name", "devcontainer.json" }
  else
    return {}
  end

  local ok_out, output = pcall(vim.system, cmd, { text = true, timeout = 10000 })
  if not ok_out or output == nil or output.code ~= 0 or not output.stdout then
    return {}
  end

  local results = {}
  local seen = {}
  for _, file in ipairs(vim.split(output.stdout, "\n", { trimempty = true })) do
    local project_dir = vim.fn.fnamemodify(file, ":h:h")
    local name = vim.fn.fnamemodify(project_dir, ":t")
    if not seen[project_dir] and vim.fn.isdirectory(project_dir) == 1 then
      seen[project_dir] = true
      table.insert(results, { name = name, path = project_dir, config_path = file })
    end
  end
  return results
end

return M
