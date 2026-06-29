local M = {}

local state = {
  last_root = nil,
  last_action = nil,
  status_cwd = nil,
  status_text = nil,
}

local CONFIG_REPO = "https://github.com/0xce3/nvim-config.git"

local function q(value)
  return vim.fn.shellescape(value or "")
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Devcontainer" })
end

local function refresh_statusline()
  pcall(function()
    require("lualine").refresh({ place = { "statusline" } })
  end)
end

function M.is_inside_container()
  return vim.fn.filereadable("/.dockerenv") == 1
    or vim.env.DEVCONTAINER == "true"
    or vim.env.REMOTE_CONTAINERS == "true"
    or vim.env.CODESPACES == "true"
    or vim.env.container ~= nil
end

function M.find_project_root(start)
  local cwd = start or vim.uv.cwd()
  local matches = vim.fs.find({ ".devcontainer", "devcontainer.json", ".git", ".vscode" }, { upward = true, path = cwd })
  if #matches == 0 then
    return cwd
  end
  local match = matches[1]
  if vim.fn.fnamemodify(match, ":t") == "devcontainer.json" then
    local dir = vim.fn.fnamemodify(match, ":h")
    return vim.fn.fnamemodify(dir, ":t") == ".devcontainer" and vim.fn.fnamemodify(dir, ":h") or dir
  end
  return vim.fs.dirname(match)
end

function M.has_devcontainer(path)
  path = path or M.find_project_root()
  return vim.fn.filereadable(path .. "/.devcontainer/devcontainer.json") == 1
    or vim.fn.filereadable(path .. "/devcontainer.json") == 1
end

local function devcontainer_cli()
  if vim.fn.executable("devcontainer") == 1 then
    return "devcontainer"
  end
  if vim.fn.executable("npx") == 1 then
    return "npx -y @devcontainers/cli"
  end
  return nil
end

local function ensure_cli()
  local cli = devcontainer_cli()
  if cli then
    return cli
  end
  notify("Install @devcontainers/cli first: npm install -g @devcontainers/cli", vim.log.levels.ERROR)
  return nil
end

local function container_bootstrap_script(workspace, workspace_name)
  local fallback_workspace = "/workspaces/" .. workspace_name
  return table.concat({
    "set -e",
    "export DEVCONTAINER=true",
    "if ! command -v nvim >/dev/null 2>&1; then",
    "  if command -v apt-get >/dev/null 2>&1; then",
    "    if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=; fi",
    "    $SUDO apt-get update || true",
    "    $SUDO apt-get install -y software-properties-common curl git ripgrep fd-find python3 python3-pip nodejs npm || true",
    "    $SUDO add-apt-repository -y ppa:neovim-ppa/unstable >/dev/null 2>&1 || true",
    "    $SUDO apt-get update || true",
    "    $SUDO apt-get install -y neovim || true",
    "  elif command -v apk >/dev/null 2>&1; then",
    "    if command -v sudo >/dev/null 2>&1; then sudo apk add --no-cache neovim git ripgrep fd python3 nodejs npm; else apk add --no-cache neovim git ripgrep fd python3 nodejs npm; fi",
    "  elif command -v dnf >/dev/null 2>&1; then",
    "    if command -v sudo >/dev/null 2>&1; then sudo dnf install -y neovim git ripgrep fd-find python3 nodejs npm; else dnf install -y neovim git ripgrep fd-find python3 nodejs npm; fi",
    "  fi",
    "fi",
    "if ! command -v nvim >/dev/null 2>&1; then echo 'nvim is not installed in this container' >&2; exit 127; fi",
    "mkdir -p \"${XDG_CONFIG_HOME:-$HOME/.config}\"",
    "if [ -d \"${XDG_CONFIG_HOME:-$HOME/.config}/nvim/.git\" ]; then",
    "  git -C \"${XDG_CONFIG_HOME:-$HOME/.config}/nvim\" pull --ff-only || true",
    "else",
    "  rm -rf \"${XDG_CONFIG_HOME:-$HOME/.config}/nvim\"",
    "  git clone " .. q(CONFIG_REPO) .. " \"${XDG_CONFIG_HOME:-$HOME/.config}/nvim\"",
    "fi",
    "workspace=" .. q(workspace),
    "if [ ! -d \"$workspace\" ]; then workspace=" .. q(fallback_workspace) .. "; fi",
    "if [ ! -d \"$workspace\" ]; then workspace=" .. q("/workspace/" .. workspace_name) .. "; fi",
    "if [ ! -d \"$workspace\" ]; then workspace=$PWD; fi",
    "cd \"$workspace\"",
    "exec nvim .",
  }, "\n")
end

local function container_bootstrap_command(workspace, workspace_name)
  return "sh -lc " .. q(container_bootstrap_script(workspace, workspace_name):gsub("exec nvim %.", "true"))
end

local function run_terminal(command)
  require("config.terminal").run(command)
end

local function replace_with_command(command)
  local script = vim.fn.tempname() .. ".sh"
  vim.fn.writefile({ "#!/usr/bin/env sh", "set -e", "clear", command }, script)
  vim.cmd("silent! wall")
  vim.cmd("redraw!")
  if vim.fn.executable("script") == 1 then
    vim.cmd("!script -q -e -c " .. q("sh " .. script) .. " /dev/null")
  else
    vim.cmd("!sh " .. q(script))
  end
  pcall(vim.fn.delete, script)
end

local function up_command(root, rebuild)
  local cli = ensure_cli()
  if not cli then
    return nil
  end
  local parts = { cli, "up", "--workspace-folder", q(root) }
  if rebuild then
    table.insert(parts, "--remove-existing-container")
  end
  return table.concat(parts, " ")
end

local function exec_nvim_command(root)
  local cli = ensure_cli()
  if not cli then
    return nil
  end
  local script = container_bootstrap_script(root, vim.fn.fnamemodify(root, ":t"))
  return table.concat({
    cli,
    "exec",
    "--workspace-folder",
    q(root),
    "sh",
    "-lc",
    q(script),
  }, " ")
end

local function docker_exec_nvim_command(container, workspace)
  local workspace_name = vim.fn.fnamemodify(workspace, ":t")
  local fallback_workspace = "/workspaces/" .. workspace_name
  local bootstrap = container_bootstrap_command(workspace, workspace_name)
  local open_workspace = table.concat({
    "workspace=" .. q(workspace),
    "if [ ! -d \"$workspace\" ]; then workspace=" .. q(fallback_workspace) .. "; fi",
    "if [ ! -d \"$workspace\" ]; then workspace=" .. q("/workspace/" .. workspace_name) .. "; fi",
    "if [ ! -d \"$workspace\" ]; then workspace=$PWD; fi",
    "cd \"$workspace\"",
    "exec nvim .",
  }, "; ")
  return table.concat({
    "docker",
    "exec",
    "-i",
    q(container),
    bootstrap,
    "&&",
    "docker",
    "exec",
    "-it",
    q(container),
    "sh",
    "-lc",
    q(open_workspace),
  }, " ")
end

local function list_running_containers()
  if vim.fn.executable("docker") == 0 then
    notify("docker is required to attach to existing containers", vim.log.levels.ERROR)
    return {}
  end
  local result = vim.system({ "docker", "ps", "--format", "{{json .}}" }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return {}
  end
  local containers = {}
  for _, line in ipairs(vim.split(result.stdout, "\n", { trimempty = true })) do
    local ok, data = pcall(vim.json.decode, line)
    if ok and data then
      table.insert(containers, {
        id = data.ID,
        name = data.Names:gsub("^/", ""),
        image = data.Image,
        status = data.Status,
      })
    end
  end
  return containers
end

local function inspect_container_workspace(container, root)
  local result = vim.system({ "docker", "inspect", container }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return "/workspaces/" .. vim.fn.fnamemodify(root, ":t")
  end
  local ok, decoded = pcall(vim.json.decode, result.stdout)
  local info = ok and decoded and decoded[1] or nil
  if not info then
    return "/workspaces/" .. vim.fn.fnamemodify(root, ":t")
  end

  local labels = info.Config and info.Config.Labels or {}
  if labels and labels["devcontainer.workspace_folder"] and labels["devcontainer.workspace_folder"] ~= "" then
    return labels["devcontainer.workspace_folder"]
  end

  local root_name = vim.fn.fnamemodify(root, ":t")
  for _, mount in ipairs(info.Mounts or {}) do
    if mount.Source == root or vim.fn.fnamemodify(mount.Source or "", ":t") == root_name then
      return mount.Destination
    end
  end

  return "/workspaces/" .. root_name
end

local function open_in_devcontainer(root, opts)
  opts = opts or {}
  root = root or M.find_project_root()
  state.last_root = root
  state.last_action = opts.rebuild and "rebuild" or "open"

  if M.is_inside_container() then
    notify("Already running inside a devcontainer", vim.log.levels.INFO)
    return
  end

  if not M.has_devcontainer(root) then
    notify("No devcontainer.json found at " .. root, vim.log.levels.WARN)
    return
  end

  if not ensure_cli() then
    return
  end

  local up = up_command(root, opts.rebuild)
  local exec_nvim = exec_nvim_command(root)
  if not up or not exec_nvim then
    return
  end

  notify((opts.rebuild and "Rebuilding" or "Opening") .. " devcontainer for " .. root)
  replace_with_command(up .. " && " .. exec_nvim)
  refresh_statusline()
end

function M.open(project_path)
  open_in_devcontainer(project_path or M.find_project_root(), { rebuild = false })
end

function M.reopen(project_path)
  M.open(project_path)
end

function M.rebuild(project_path)
  open_in_devcontainer(project_path or M.find_project_root(), { rebuild = true })
end

function M.connect()
  M.attach()
end

function M.attach(container_name, project_path)
  local root = project_path or M.find_project_root()
  if container_name and container_name ~= "" then
    local workspace = inspect_container_workspace(container_name, root)
    notify("Attaching to " .. container_name)
    replace_with_command(docker_exec_nvim_command(container_name, workspace))
    return
  end

  local containers = list_running_containers()
  if #containers == 0 then
    notify("No running containers found", vim.log.levels.WARN)
    return
  end

  local ok_telescope, pickers = pcall(require, "telescope.pickers")
  if not ok_telescope then
    local items = {}
    for _, c in ipairs(containers) do
      table.insert(items, c.name .. "  " .. c.image .. "  " .. c.status)
    end
    vim.ui.select(items, { prompt = "Attach nvim to running container:" }, function(choice, idx)
      if choice and idx then
        M.attach(containers[idx].name, root)
      end
    end)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  pickers
    .new({}, {
      prompt_title = "Attach Running Container",
      finder = finders.new_table({
        results = containers,
        entry_maker = function(c)
          local display = c.name .. "  " .. c.image .. "  " .. c.status
          return { value = c, display = display, ordinal = display }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value then
            M.attach(selection.value.name, root)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.menu(project_path)
  local root = project_path or M.find_project_root()
  local ok_telescope, pickers = pcall(require, "telescope.pickers")
  if not ok_telescope then
    vim.ui.select({ "Attach to Running Container", "Reopen in Devcontainer", "Rebuild Devcontainer", "Open Shell", "Stop Devcontainer" }, {
      prompt = "Devcontainer",
    }, function(choice)
      if choice == "Attach to Running Container" then
        M.attach(nil, root)
      elseif choice == "Reopen in Devcontainer" then
        M.reopen(root)
      elseif choice == "Rebuild Devcontainer" then
        M.rebuild(root)
      elseif choice == "Open Shell" then
        M.shell(root)
      elseif choice == "Stop Devcontainer" then
        M.stop(root)
      end
    end)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local entries = {}
  if M.is_inside_container() then
    entries = {
      { label = "Rebuild Devcontainer", action = function() M.rebuild(root) end, ordinal = "rebuild devcontainer" },
      { label = "Open Local Workspace", action = function() notify("Open a local shell and run nvim " .. root, vim.log.levels.INFO) end, ordinal = "open local workspace" },
      { label = "Open Devcontainer Shell", action = function() M.shell(root) end, ordinal = "shell devcontainer" },
      { label = "Stop Devcontainer", action = function() M.stop(root) end, ordinal = "stop devcontainer" },
    }
  else
    entries = {
      { label = "Attach to running container", action = function() M.attach(nil, root) end, ordinal = "attach running container" },
      { label = "Reopen in Devcontainer", action = function() M.reopen(root) end, ordinal = "reopen devcontainer" },
      { label = "Rebuild Devcontainer", action = function() M.rebuild(root) end, ordinal = "rebuild devcontainer" },
      { label = "Open Devcontainer Shell", action = function() M.shell(root) end, ordinal = "shell devcontainer" },
      { label = "Stop Devcontainer", action = function() M.stop(root) end, ordinal = "stop devcontainer" },
    }
  end

  for _, c in ipairs(list_running_containers()) do
    table.insert(entries, {
      label = "Attach: " .. c.name .. "  " .. c.image,
      ordinal = "attach " .. c.name .. " " .. c.image,
      action = function()
        M.attach(c.name, root)
      end,
    })
  end

  pickers
    .new({}, {
      prompt_title = "Devcontainer: " .. vim.fn.fnamemodify(root, ":t"),
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return { value = entry, display = entry.label, ordinal = entry.ordinal }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value and selection.value.action then
            selection.value.action()
          end
        end)
        return true
      end,
    })
    :find()
end

function M.shell(project_path)
  local root = project_path or M.find_project_root()
  if not M.has_devcontainer(root) then
    notify("No devcontainer.json found at " .. root, vim.log.levels.WARN)
    return
  end
  local cli = ensure_cli()
  if not cli then
    return
  end
  run_terminal(cli .. " exec --workspace-folder " .. q(root) .. " sh -l")
end

function M.stop(project_path)
  local root = project_path or state.last_root or M.find_project_root()
  if vim.fn.executable("docker") == 0 then
    notify("docker is required to stop devcontainers", vim.log.levels.ERROR)
    return
  end
  run_terminal("docker ps -q --filter " .. q("label=devcontainer.local_folder=" .. root) .. " | xargs -r docker stop")
end

function M.kill(project_path)
  M.stop(project_path)
end

function M.restart(project_path)
  M.rebuild(project_path)
end

function M.statusline()
  if M.is_inside_container() then
    return ""
  end
  local cwd = vim.uv.cwd()
  if state.status_cwd == cwd and state.status_text then
    return state.status_text
  end
  local root = M.find_project_root()
  state.status_cwd = cwd
  if M.has_devcontainer(root) then
    state.status_text = ""
    return state.status_text
  end
  state.status_text = ""
  return state.status_text
end

function M.statusline_color()
  if M.is_inside_container() then
    return { fg = "#2496ed", gui = "bold" }
  end
  return { fg = "#928374" }
end

function M.setup()
  vim.api.nvim_create_user_command("DevcontainerReopen", function(opts)
    M.reopen(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Reopen project in devcontainer" })

  vim.api.nvim_create_user_command("DevcontainerConnect", function()
    M.connect()
  end, { desc = "Open nvim in this project's devcontainer" })

  vim.api.nvim_create_user_command("DevcontainerAttach", function(opts)
    M.attach(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", complete = "shellcmd", desc = "Attach nvim to a running Docker container" })

  vim.api.nvim_create_user_command("DevcontainerHub", function()
    M.menu()
  end, { desc = "Open devcontainer action menu" })

  vim.api.nvim_create_user_command("DevcontainerMenu", function(opts)
    M.menu(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Open devcontainer action menu" })

  vim.api.nvim_create_user_command("DevcontainerUp", function(opts)
    M.open(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Build/start devcontainer and open nvim inside it" })

  vim.api.nvim_create_user_command("DevcontainerStop", function(opts)
    M.stop(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Stop this project's devcontainer" })

  vim.api.nvim_create_user_command("DevcontainerRebuild", function(opts)
    M.rebuild(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Rebuild devcontainer and open nvim inside it" })

  vim.api.nvim_create_user_command("DevcontainerShell", function(opts)
    M.shell(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Open shell in this project's devcontainer" })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("DevcontainerHub", { clear = true }),
    callback = refresh_statusline,
  })
end

function M.info()
  return {
    inside_container = M.is_inside_container(),
    project_path = M.find_project_root(),
    has_devcontainer = M.has_devcontainer(M.find_project_root()),
    cli = devcontainer_cli(),
  }
end

return M
