local M = {}

local function project_root(bufnr)
  return vim.fs.root(bufnr, { ".git" }) or vim.fn.getcwd()
end

local function lsp_root_dir(bufnr, on_dir)
  on_dir(project_root(bufnr))
end

local function reload_current_buffer()
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(0) then vim.cmd("silent! edit") end
  end)
end

function M.setup_yaml()
  local registry = require("mason-registry")
  local package_name = "yaml-language-server"

  local function ensure_prettierd()
    local formatter = "prettierd"
    if not registry.has_package(formatter) then return end
    local package = registry.get_package(formatter)
    if package:is_installed() then return end
    vim.notify("Installing prettierd...", vim.log.levels.INFO, { title = "Yocto" })
    package:install()
  end

  local function configure()
    vim.lsp.config("yamlls", {
      cmd = { "yaml-language-server", "--stdio" },
      filetypes = { "yaml" },
      root_dir = lsp_root_dir,
      settings = {
        yaml = {
          schemaStore = { enable = true },
          validate = true,
          hover = true,
          completion = true,
        },
      },
    })
    vim.lsp.enable("yamlls", true)
    ensure_prettierd()
    reload_current_buffer()
  end

  local function install()
    local package = registry.get_package(package_name)
    if package:is_installed() then
      configure()
      return
    end
    vim.notify("Installing yaml-language-server...", vim.log.levels.INFO, { title = "Yocto" })
    package:once("install:success", configure)
    package:once("install:failed", function()
      vim.notify("Failed to install yaml-language-server", vim.log.levels.ERROR, { title = "Yocto" })
    end)
    package:install()
  end

  if registry.has_package(package_name) then
    install()
  else
    registry.refresh(function()
      if registry.has_package(package_name) then install() end
    end)
  end
end

local function bitbake_server()
  local venv = vim.env.PYTHON_VENV
  local candidate = venv and vim.fs.joinpath(venv, "bin", "bitbake-language-server") or nil
  if candidate and vim.fn.executable(candidate) == 1 then return candidate end
  local command = vim.fn.exepath("bitbake-language-server")
  return command ~= "" and command or nil
end

function M.setup_bitbake()
  local function configure(command)
    vim.lsp.config("bitbake_ls", {
      cmd = { command },
      filetypes = { "bitbake" },
      root_dir = lsp_root_dir,
    })
    vim.lsp.enable("bitbake_ls", true)
    reload_current_buffer()
  end

  local command = bitbake_server()
  if command then
    configure(command)
    return
  end

  local python = vim.env.PYTHON_VENV and vim.fs.joinpath(vim.env.PYTHON_VENV, "bin", "python")
    or vim.fn.exepath("python3")
  if not python or python == "" or vim.fn.executable(python) ~= 1 then
    vim.notify("Python is required to install bitbake-language-server", vim.log.levels.ERROR, { title = "Yocto" })
    return
  end

  local install = { python, "-m", "pip", "install" }
  if not vim.env.PYTHON_VENV or vim.env.PYTHON_VENV == "" then table.insert(install, "--user") end
  table.insert(install, "bitbake-language-server")
  vim.notify("Installing Freed-Wu/bitbake-language-server...", vim.log.levels.INFO, { title = "Yocto" })
  vim.system(install, { text = true }, function(result)
    vim.schedule(function()
      command = bitbake_server()
      if result.code == 0 and command then
        configure(command)
      else
        vim.notify(result.stderr ~= "" and result.stderr or "Failed to install bitbake-language-server", vim.log.levels.ERROR, { title = "Yocto" })
      end
    end)
  end)
end

return M
