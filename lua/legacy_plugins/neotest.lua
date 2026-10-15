local function find_task_root()
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

local function pytest_args(root)
  local settings = read_vscode_settings(root)
  local args = settings["python.testing.pytestArgs"] or { "tests/system" }
  local test_root = vim.fs.joinpath(root, "tests", "system")
  local result = {}
  for _, arg in ipairs(args) do
    arg = expand_vars(arg, root)
    if type(arg) == "string" and arg:match("^%-%-rootdir=") then
      table.insert(result, "--rootdir=" .. test_root)
    elseif type(arg) == "string" and arg:sub(1, 1) ~= "-" and (arg == "tests/system" or arg == test_root) then
      -- Neotest appends the selected file/test itself. Keeping VS Code's
      -- positional test target here makes pytest receive duplicate targets.
    elseif type(arg) == "string" and arg:match("^%-%-[^=]+-path=") then
      -- Ignore stale absolute paths from a different host/container. The
      -- project task or environment can still provide a valid path explicitly.
      local value = arg:match("^[^=]+=([^=]+)$")
      if value and vim.fn.filereadable(value) == 1 then table.insert(result, arg) end
    else
      table.insert(result, arg)
    end
  end
  if vim.fn.filereadable(vim.fs.joinpath(test_root, "pytest.ini")) == 1 then
    local has_rootdir = false
    for _, arg in ipairs(result) do
      if type(arg) == "string" and arg:match("^%-%-rootdir=") then
        has_rootdir = true
        break
      end
    end
    if not has_rootdir then
      table.insert(result, "--rootdir=" .. test_root)
    end
  end
  return result
end

local function python_path(root)
  local python_env = require("config.python_env")
  local settings = read_vscode_settings(root)
  local configured = expand_vars(settings["python.defaultInterpreterPath"], root)
  if configured and vim.fn.executable(configured) == 1 then
    return configured
  end
  return python_env.python(root)
end

local state = {}

-- Neotest evaluates adapter callbacks from libuv fast events. Cache all values
-- that require Vim API calls before starting a test, so those callbacks remain
-- safe in that context.
local function refresh_state()
  local root = find_task_root()
  state.root = root
  state.python = python_path(root)
  state.pytest_args = pytest_args(root)
  state.test_root = vim.fs.joinpath(root, "tests", "system")
  state.has_test_root = vim.fn.isdirectory(state.test_root) == 1
  return state
end

local function task_root()
  return state.root or refresh_state().root
end

local function is_under(path, root)
  local prefix = root:match("/$") and root or root .. "/"
  return path == root or path:find(prefix, 1, true) == 1
end

local function current_unit_test_root()
  local path = vim.api.nvim_buf_get_name(0)
  local root = task_root()
  if path == "" or not root or not is_under(path, vim.fs.joinpath(root, "tests", "unit")) then
    return nil
  end
  local testcase = vim.fs.find("testcase.yaml", {
    path = vim.fs.dirname(path),
    upward = true,
    limit = 1,
  })[1]
  return testcase and vim.fs.dirname(testcase) or nil
end

local function run_current_unit_test()
  local unit_root = current_unit_test_root()
  if not unit_root then
    vim.notify("Open a file below tests/unit to run its suite", vim.log.levels.WARN, { title = "unit tests" })
    return
  end

  local root = task_root()
  local relative_root = unit_root:sub(#root + 2)
  local profiles = {
    { label = "GCC with ASAN", task = "Run specific Unit Test on native_sim (GCC) (ASAN)" },
    { label = "Clang with ASAN", task = "Run specific Unit Test on native_sim (Clang) (ASAN)" },
    { label = "GCC with Valgrind", task = "Run specific Unit Test on native_sim (GCC) (Valgrind)" },
    { label = "Clang with Valgrind", task = "Run specific Unit Test on native_sim (Clang) (Valgrind)" },
  }
  vim.ui.select(profiles, {
    prompt = "Run " .. relative_root,
    format_item = function(profile) return profile.label end,
  }, function(profile)
    if profile then
      require("config.vscode_debug").run_task(profile.task, { test_path = relative_root })
    end
  end)
end

local function python_adapter()
  refresh_state()
  local adapter = require("neotest-python")({
    python = function()
      return state.python
    end,
    pytest_discover_instances = true,
    args = function()
      return state.pytest_args
    end,
  })
  adapter.root = function(path)
    local root = state.root
    local test_root = state.test_root
    if type(path) == "string" and root and state.has_test_root and test_root and is_under(path, root) then
      return test_root
    end
    return nil
  end
  return adapter
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
      {
        "<leader>tn",
        function()
          refresh_state()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>tf",
        function()
          refresh_state()
          local neotest = require("neotest")
          neotest.run.run(vim.fn.expand("%"))
          vim.schedule(function()
            neotest.summary.open()
          end)
        end,
        desc = "Run test file",
      },
      {
        "<leader>ta",
        function()
          local root = refresh_state().root
          require("neotest").run.run(root .. "/tests/system")
        end,
        desc = "Run system tests",
      },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Test output" },
      { "<leader>tp", function() require("neotest").summary.toggle() end, desc = "Test panel" },
      { "<leader>tx", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "<leader>tu", run_current_unit_test, desc = "Run current unit suite" },
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
          python_adapter(),
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
