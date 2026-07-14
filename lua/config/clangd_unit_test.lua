-- Start a dedicated clangd instance for Zephyr Twister unit tests.  The normal
-- firmware compile database lacks ZTEST/FFF definitions, so it cannot lint
-- tests/unit/** correctly.

local M = {}

local compile_database_cache = {}
local pending_lookups = {}
local warned_roots = {}

function M.is_unit_test(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  return path:find("/tests/unit/", 1, true) ~= nil
end

local function test_root(bufnr)
  if not M.is_unit_test(bufnr) then return nil end
  local path = vim.api.nvim_buf_get_name(bufnr)
  local testcase = vim.fs.find("testcase.yaml", {
    path = vim.fs.dirname(path),
    upward = true,
    limit = 1,
  })[1]
  return testcase and vim.fs.dirname(testcase) or nil
end

local function database_contains_source(path, source)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and table.concat(lines, "\n"):find(source, 1, true) ~= nil
end

local function latest_database(paths)
  table.sort(paths, function(a, b)
    local a_stat = vim.uv.fs_stat(a)
    local b_stat = vim.uv.fs_stat(b)
    local a_mtime = a_stat and a_stat.mtime.sec or 0
    local b_mtime = b_stat and b_stat.mtime.sec or 0
    return a_mtime > b_mtime
  end)
  return paths[1]
end

local function cached_compile_commands_dir(root)
  local cached = compile_database_cache[root]
  if cached and vim.fn.filereadable(cached .. "/compile_commands.json") == 1 then
    return cached
  end
end

local function find_compile_commands_dir(root, callback)
  local cached = cached_compile_commands_dir(root)
  if cached then
    callback(cached)
    return
  end

  if pending_lookups[root] then
    table.insert(pending_lookups[root], callback)
    return
  end
  pending_lookups[root] = { callback }

  local project = vim.fs.root(root, { ".git" })
  local source = root .. "/src/main.c"
  if not project or vim.fn.filereadable(source) ~= 1 then
    pending_lookups[root] = nil
    callback(nil)
    return
  end

  vim.system({ "find", project, "-type", "f", "-name", "compile_commands.json" }, { text = true }, function(result)
    local matches = {}
    if result.code == 0 then
      for _, path in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
        if path:find("twister-out", 1, true) and database_contains_source(path, source) then
          table.insert(matches, path)
        end
      end
    end

    local database = latest_database(matches)
    local directory = database and vim.fs.dirname(database) or nil
    if directory then compile_database_cache[root] = directory end

    vim.schedule(function()
      local callbacks = pending_lookups[root] or {}
      pending_lookups[root] = nil
      for _, pending_callback in ipairs(callbacks) do
        pending_callback(directory)
      end
    end)
  end)
end

function M.root_dir(bufnr, on_dir)
  local root = test_root(bufnr)
  if not root then return end
  find_compile_commands_dir(root, function(directory)
    if directory then
      on_dir(root)
    elseif not warned_roots[root] then
      warned_roots[root] = true
      vim.notify("No Twister compile database found for " .. root, vim.log.levels.WARN, { title = "clangd" })
    end
  end)
end

function M.cmd(dispatchers, config)
  local directory = cached_compile_commands_dir(config.root_dir)
  local cmd = { "clangd" }
  if directory then table.insert(cmd, "--compile-commands-dir=" .. directory) end
  return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
end

return M
