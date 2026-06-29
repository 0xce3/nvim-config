local M = {}

local docker_available = nil

function M.is_docker_available()
  if docker_available ~= nil then
    return docker_available
  end
  if vim.fn.executable("docker") == 0 then
    docker_available = false
    return false
  end
  local ok, result = pcall(vim.system, { "docker", "info", "--format", "{{.ServerVersion}}" }, { text = true })
  docker_available = ok and result.code == 0
  return docker_available
end

function M.list_running_containers()
  if not M.is_docker_available() then
    return {}
  end

  local ok_result, result = pcall(vim.system, { "docker", "ps", "--format", "{{json .}}" }, { text = true })
  if not ok_result or result.code ~= 0 or not result.stdout then
    return {}
  end

  local containers = {}
  for _, line in ipairs(vim.split(result.stdout, "\n", { trimempty = true })) do
    local ok, data = pcall(vim.json.decode, line)
    if ok and data then
      local ok_inspect, inspect = pcall(vim.system,
        { "docker", "inspect", data.ID, "--format", "{{json .Config.Labels}}" },
        { text = true })
      local labels = {}
      if ok_inspect and inspect.code == 0 and inspect.stdout then
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

  return containers
end

function M.get_container_workspace_folder(container_id)
  if not M.is_docker_available() then
    return nil
  end
  local ok, result = pcall(vim.system,
    { "docker", "inspect", container_id, "--format", "{{index .Config.Labels \"devcontainer.local_folder\"}}" },
    { text = true })
  if ok and result.code == 0 and result.stdout then
    local folder = vim.trim(result.stdout)
    return folder ~= "" and folder or nil
  end
  return nil
end

function M.find_devcontainer_projects(search_base)
  search_base = search_base or vim.env.HOME
  local results = {}

  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = { "fd", "devcontainer.json", search_base, "--type", "f", "--hidden", "--no-ignore" }
  elseif vim.fn.executable("find") == 1 then
    cmd = { "find", search_base, "-type", "f", "-name", "devcontainer.json" }
  else
    return results
  end

  local ok_out, output = pcall(vim.system, cmd, { text = true })
  if not ok_out or output.code ~= 0 or not output.stdout then
    return results
  end

  local seen = {}
  for _, file in ipairs(vim.split(output.stdout, "\n", { trimempty = true })) do
    local project_dir = vim.fn.fnamemodify(file, ":h:h")
    local name = vim.fn.fnamemodify(project_dir, ":t")
    if not seen[project_dir] then
      seen[project_dir] = true
      table.insert(results, {
        name = name,
        path = project_dir,
        config_path = file,
      })
    end
  end

  return results
end

return M
