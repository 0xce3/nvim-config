-- Quickly switch the active clangd compile database between build directories.
--
-- Telescope lists every compile_commands.json under the project root. Picking
-- one points clangd at that build directory via `--compile-commands-dir` and
-- restarts clangd. The choice is remembered in Neovim's state dir (see
-- config.clangd_build) so it survives restarts without creating project files.
--
-- Keymap: <leader>fc

local store = require("config.clangd_build")

-- Substrings; any compile_commands.json whose path contains one is hidden.
local EXCLUDE = vim.g.compile_commands_exclude or {}

local function filter_ccjson(root, raw)
  local root_file = root .. "/compile_commands.json"
  local results = {}
  for _, f in ipairs(raw) do
    -- Keep only real compile_commands.json paths (guards against any stray
    -- non-path lines), drop any stray root file and excluded builds.
    if f:match("compile_commands%.json$") and f ~= root_file then
      local skip = false
      for _, pat in ipairs(EXCLUDE) do
        if f:find(pat, 1, true) then
          skip = true
          break
        end
      end
      if not skip then
        table.insert(results, f)
      end
    end
  end
  table.sort(results)
  return results
end

local function find_ccjson(root, callback)
  local raw = {}
  if vim.fn.executable("find") == 1 then
    -- Run find directly (no shell) so the user's login-shell startup noise
    -- ("bash: no job control...") never leaks into the results.
    vim.system({ "find", root, "-type", "f", "-name", "compile_commands.json" }, { text = true }, function(res)
      if res.stdout and res.stdout ~= "" then
        raw = vim.split(res.stdout, "\n", { trimempty = true })
      end
      vim.schedule(function()
        callback(filter_ccjson(root, raw))
      end)
    end)
    return
  end

  if vim.tbl_isempty(raw) then
    raw = vim.fs.find("compile_commands.json", { path = root, type = "file", limit = 1000 })
  end
  callback(filter_ccjson(root, raw))
end

local function restart_clangd(build_dir)
  -- Point clangd at the chosen build's compile_commands.json directory.
  vim.lsp.config("clangd", { cmd = { "clangd", "--compile-commands-dir=" .. build_dir } })
  vim.lsp.enable("clangd", true)

  -- Stop the running clangd GRACEFULLY (no force): a forced stop sends a signal
  -- and clangd then exits with status 1, which Neovim reports as the scary
  -- "Client clangd quit with exit code 1". A graceful stop lets it exit 0.
  for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    client:stop()
  end
  -- Re-attach (auto-attach re-reads the new cmd) once the old client is gone.
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(0) then
      pcall(vim.cmd, "edit")
    end
  end, 600)
end

local function switch_compile_commands()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local root = vim.fn.getcwd()
  local saved = store.get(root)

  vim.notify("Searching compile_commands.json...", vim.log.levels.INFO, { title = "clangd" })
  find_ccjson(root, function(results)
    if vim.tbl_isempty(results) then
      vim.notify("No build compile_commands.json found under " .. root, vim.log.levels.WARN)
      return
    end

    pickers
      .new({}, {
        prompt_title = "Switch clangd build (compile_commands.json)",
        finder = finders.new_table({
          results = results,
          entry_maker = function(entry)
            local rel = vim.fn.fnamemodify(entry, ":.")
            local active = (vim.fn.fnamemodify(entry, ":h") == saved) and "  ●" or ""
            return { value = entry, display = rel .. active, ordinal = rel }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not selection then
              return
            end
            local target = selection.value
            local build_dir = vim.fn.fnamemodify(target, ":h")

            -- Remember the choice in Neovim's state dir (not in the repo).
            store.set(root, build_dir)

            restart_clangd(build_dir)
            pcall(function()
              require("lualine").refresh({ place = { "statusline" } })
            end)
            vim.notify(
              "clangd build -> " .. vim.fn.fnamemodify(build_dir, ":."),
              vim.log.levels.INFO,
              { title = "clangd" }
            )
          end)
          return true
        end,
      })
      :find()
  end)
end

return {
  "nvim-telescope/telescope.nvim",
  keys = {
    {
      "<leader>fc",
      switch_compile_commands,
      desc = "Switch clangd build (compile_commands)",
    },
  },
}
