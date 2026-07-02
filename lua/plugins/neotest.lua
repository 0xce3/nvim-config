local function task_root()
  return require("config.vscode_debug").find_task_root()
end

local function read_vscode_settings(root)
  local path = vim.fs.joinpath(root, ".vscode", "settings.json")
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local text = table.concat(vim.fn.readfile(path), "\n")
  local ok, parsed = pcall(require("config.vscode_debug").decode_jsonc, text)
  if not ok or type(parsed) ~= "table" then
    return {}
  end
  return parsed
end

local function expand_vars(value, root)
  if type(value) ~= "string" then
    return value
  end
  return require("config.vscode_debug").expand_vscode_vars(value, root)
end

local function pytest_args()
  local root = task_root()
  local settings = read_vscode_settings(root)
  local args = settings["python.testing.pytestArgs"] or { "tests/system" }
  return vim.tbl_map(function(arg)
    return expand_vars(arg, root)
  end, args)
end

local function python_path()
  local root = task_root()
  local settings = read_vscode_settings(root)
  local configured = expand_vars(settings["python.defaultInterpreterPath"], root)
  if configured and vim.fn.executable(configured) == 1 then
    return configured
  end
  return vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python3"
end

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
    },
    keys = {
      { "<leader>tn", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run test file" },
      { "<leader>ta", function() require("neotest").run.run(task_root() .. "/tests/system") end, desc = "Run system tests" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Test output" },
      { "<leader>tp", function() require("neotest").summary.toggle() end, desc = "Test panel" },
      { "<leader>tx", function() require("neotest").run.stop() end, desc = "Stop test" },
      {
        "<leader>tS",
        function()
          require("config.vscode_debug").run_task("Run all System Tests on " .. "native" .. "_" .. "sim" .. " (Clang)")
        end,
        desc = "Run VS Code system tests",
      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            python = python_path,
            pytest_discover_instances = true,
            args = pytest_args,
          }),
        },
        output = {
          open_on_run = false,
        },
        summary = {
          animated = true,
          enabled = true,
          follow = true,
        },
      })
    end,
  },
}
