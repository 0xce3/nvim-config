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

local function container_bootstrap_script(workspace)
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
    "cd " .. q(workspace),
    "exec nvim .",
  }, "\n")
end

local function run_terminal(command)
  require("config.terminal").run(command)
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
  local script = container_bootstrap_script(root)
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
  run_terminal(up .. " && " .. exec_nvim)
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
  M.open(M.find_project_root())
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
    return "devcontainer"
  end
  local cwd = vim.uv.cwd()
  if state.status_cwd == cwd and state.status_text then
    return state.status_text
  end
  local root = M.find_project_root()
  state.status_cwd = cwd
  if M.has_devcontainer(root) then
    state.status_text = "host:devcontainer"
    return state.status_text
  end
  state.status_text = "host"
  return state.status_text
end

function M.prompt_for_current_project()
  if M.is_inside_container() then
    return
  end
  local root = M.find_project_root()
  if not M.has_devcontainer(root) then
    return
  end
  vim.ui.select({ "Reopen in Devcontainer", "Open locally" }, {
    prompt = vim.fn.fnamemodify(root, ":t") .. " has a devcontainer.json",
  }, function(choice)
    if choice == "Reopen in Devcontainer" then
      M.reopen(root)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("DevcontainerReopen", function(opts)
    M.reopen(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Reopen project in devcontainer" })

  vim.api.nvim_create_user_command("DevcontainerConnect", function()
    M.connect()
  end, { desc = "Open nvim in this project's devcontainer" })

  vim.api.nvim_create_user_command("DevcontainerHub", function()
    require("config.workspace_hub").open()
  end, { desc = "Open workspace hub" })

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

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("DevcontainerHub", { clear = true }),
    callback = function()
      vim.defer_fn(function()
        M.prompt_for_current_project()
        refresh_statusline()
      end, 300)
    end,
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
