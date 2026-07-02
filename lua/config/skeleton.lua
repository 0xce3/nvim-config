local M = {}

local function repo_root()
  return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
end

local function relative_path(path, root)
  local prefix = root:match("/$") and root or root .. "/"
  if path:find(prefix, 1, true) == 1 then
    return path:sub(#prefix + 1)
  end
  return path
end

local function basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

local function dirname(path)
  return vim.fn.fnamemodify(path, ":h:t")
end

local function module_name(path, kind, root)
  local rel = relative_path(path, root)
  local file_base = vim.fn.fnamemodify(path, ":t:r")

  if kind == "header" and rel:match("include/qmx/[^/]+/[^/]+%.h$") then
    return file_base
  end

  if kind == "source" and basename(path) == dirname(path) .. ".c" then
    return file_base
  end

  return dirname(path)
end

local function generate(kind)
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Save the buffer before generating a skeleton", vim.log.levels.WARN, { title = "Skeleton" })
    return
  end

  local ext = vim.fn.fnamemodify(path, ":e")
  if (kind == "source" and ext ~= "c") or (kind == "header" and ext ~= "h") then
    vim.notify("Current buffer is not a ." .. (kind == "source" and "c" or "h") .. " file", vim.log.levels.WARN, { title = "Skeleton" })
    return
  end

  if vim.api.nvim_buf_line_count(0) > 1 or (vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or "") ~= "" then
    vim.notify("Skeleton generation only runs for empty buffers", vim.log.levels.WARN, { title = "Skeleton" })
    return
  end

  local root = repo_root()
  local script = root .. "/scripts/skeleton_" .. kind .. ".py"
  if vim.fn.filereadable(script) ~= 1 then
    vim.notify("scripts/skeleton_" .. kind .. ".py not found", vim.log.levels.ERROR, { title = "Skeleton" })
    return
  end

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local py = table.concat({
    "import sys",
    "sys.path.insert(0, sys.argv[1])",
    "name = sys.argv[2]",
    "module = sys.argv[3]",
    "kind = sys.argv[4]",
    "if kind == 'source':",
    "    from skeleton_source import skeleton_source as skeleton",
    "else:",
    "    from skeleton_header import skeleton_header as skeleton",
    "sys.stdout.write(''.join(skeleton(name, module)))",
  }, "\n")
  local result = vim.system({
    "python3",
    "-c",
    py,
    root .. "/scripts",
    basename(path),
    module_name(path, kind, root),
    kind,
  }, { cwd = root, text = true }):wait()
  if result.code ~= 0 then
    vim.notify(vim.trim((result.stderr or "") .. "\n" .. (result.stdout or "")), vim.log.levels.ERROR, { title = "Skeleton" })
    return
  end

  local lines = vim.split(result.stdout or "", "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.notify("Generated " .. kind .. " skeleton", vim.log.levels.INFO, { title = "Skeleton" })
end

function M.setup()
  vim.api.nvim_create_user_command("SkeletonSource", function()
    generate("source")
  end, { desc = "Generate compliance C source skeleton" })

  vim.api.nvim_create_user_command("SkeletonHeader", function()
    generate("header")
  end, { desc = "Generate compliance C header skeleton" })

  vim.api.nvim_create_user_command("Skeleton", function(opts)
    local kind = opts.args:lower()
    if kind == "source" then
      generate("source")
    elseif kind == "header" then
      generate("header")
    else
      vim.notify("Use :Skeleton source or :Skeleton header", vim.log.levels.WARN, { title = "Skeleton" })
    end
  end, {
    complete = function()
      return { "source", "header" }
    end,
    desc = "Generate compliance C skeleton",
    nargs = 1,
  })

  vim.keymap.set("n", "<leader>cs", "<cmd>SkeletonSource<cr>", { desc = "Generate source skeleton" })
  vim.keymap.set("n", "<leader>ch", "<cmd>SkeletonHeader<cr>", { desc = "Generate header skeleton" })
end

return M
