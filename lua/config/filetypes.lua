-- Syntax highlighting for Kconfig-style fragment files (.conf) that contain
-- CONFIG_FOO=y assignments.
-- Neovim does not highlight these out of the box.

-- Map *.conf to a dedicated filetype. A custom name ("kconf") is used on
-- purpose so it never clashes with the Treesitter "kconfig" parser, which
-- targets Kconfig *definition* files (config/menu/...) rather than these
-- key=value fragments.
vim.filetype.add({
  extension = {
    conf = "kconf",
    http = "http",
    rest = "http",
  },
})

local function treesitter_disabled_for_buffer(bufnr, lang)
  if lang == "markdown" or lang == "markdown_inline" then
    return true
  end

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == "markdown" or filetype == "markdown_inline" then
    return true
  end

  return vim.bo[bufnr].buftype == "nofile"
end

if not vim.g.nvim_config_treesitter_start_guard then
  vim.g.nvim_config_treesitter_start_guard = true
  local treesitter_start = vim.treesitter.start
  vim.treesitter.start = function(bufnr, lang, ...)
    if bufnr == nil or bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    if treesitter_disabled_for_buffer(bufnr, lang) then
      return
    end
    return treesitter_start(bufnr, lang, ...)
  end
end

-- Lightweight syntax for CONFIG_*=value fragment files.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "kconf",
  callback = function()
    vim.bo.commentstring = "# %s"
    vim.bo.comments = ":#"
    vim.cmd([=[
      syntax clear
      syntax region  kconfComment  start="#" end="$" oneline contains=@Spell
      syntax region  kconfString   start=+"+ skip=+\\"+ end=+"+
      syntax match   kconfNumber   "\<0x\x\+\>"
      syntax match   kconfNumber   "\<\d\+\>"
      syntax keyword kconfBool      y n m
      syntax match   kconfKey       "\<CONFIG_\w\+"
      syntax match   kconfKey       "^\s*\w\+\ze\s*="
      syntax match   kconfOperator  "="

      highlight default link kconfComment  Comment
      highlight default link kconfString   String
      highlight default link kconfNumber   Number
      highlight default link kconfBool      Boolean
      highlight default link kconfKey       Identifier
      highlight default link kconfOperator  Operator
    ]=])
  end,
})

-- Fallback highlighting for .http/.rest files. kulala.nvim provides richer
-- parsing when its Treesitter support is installed, but this keeps generated
-- request files readable immediately in fresh containers.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "http",
  callback = function()
    vim.bo.commentstring = "# %s"
    vim.bo.comments = ":#"
    vim.cmd([=[
      syntax clear
      syntax region  httpComment      start="#" end="$" oneline contains=@Spell
      syntax region  httpJsonString   start=+"+ skip=+\\"+ end=+"+
      syntax match   httpSection      "^###.*$"
      syntax match   httpVariable     "{{[^}]*}}"
      syntax match   httpDefinition   "^@[A-Za-z0-9_.-]\+\s*="
      syntax match   httpHeader       "^[A-Za-z0-9_-]\+:\ze\s"
      syntax match   httpUrl          "https\?://[^[:space:]]\+"
      syntax match   httpMethod       "^\s*\(GET\|POST\|PUT\|PATCH\|DELETE\|HEAD\|OPTIONS\)\>"
      syntax match   httpStatus       "\<\d\{3}\>"
      syntax keyword httpBool         true false null

      highlight default link httpComment     Comment
      highlight default link httpJsonString  String
      highlight default link httpSection     Title
      highlight default link httpVariable    Identifier
      highlight default link httpDefinition  Define
      highlight default link httpHeader      Type
      highlight default link httpUrl         Underlined
      highlight default link httpMethod      Keyword
      highlight default link httpStatus      Number
      highlight default link httpBool        Boolean
    ]=])
  end,
})

-- Kulala response panes are Markdown scratch buffers containing nested fenced
-- payloads. Some Neovim/Treesitter parser combinations throw in decoration
-- callbacks there; plain syntax highlighting is more reliable for responses.
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
  callback = function(event)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
      end
      local buftype = vim.bo[event.buf].buftype
      local filetype = vim.bo[event.buf].filetype
      if buftype == "nofile" and (filetype == "markdown" or filetype == "markdown_inline") then
        pcall(vim.treesitter.stop, event.buf)
        vim.bo[event.buf].syntax = "markdown"
      end
    end)
  end,
})

-- Hide the kulala output window when leaving an http/rest file,
-- and restore it when re-entering.  The response buffer itself is
-- kept alive so the last result reappears without re-running.
local function kulala_hide_output()
  local ok, kulala = pcall(require, "kulala.ui")
  if not ok then return end
  local win = kulala.get_kulala_window()
  if win then pcall(vim.api.nvim_win_close, win, true) end
end

local function kulala_show_output()
  -- Don't fire during initial UI setup; only once kulala is loaded.
  local ok, kulala = pcall(require, "kulala.ui")
  if not ok then return end
  local buf = kulala.get_kulala_buffer()
  if not buf then return end
  local wins = vim.fn.win_findbuf(buf)
  if #wins > 0 then return end
  local ok_cfg, config = pcall(require, "kulala.config")
  local split_dir = ok_cfg and config.get().ui.split_direction or "right"
  pcall(vim.api.nvim_open_win, buf, false, {
    split = split_dir,
    win = vim.api.nvim_get_current_win(),
  })
end

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.http", "*.rest" },
  callback = kulala_hide_output,
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "*.http", "*.rest" },
  callback = kulala_show_output,
})

-- When the http/rest file itself is closed there is no way back
-- to the response, so clean it up.
vim.api.nvim_create_autocmd("BufUnload", {
  pattern = { "*.http", "*.rest" },
  callback = function()
    local ok, kulala = pcall(require, "kulala.ui")
    if ok then pcall(kulala.close_kulala_buffer) end
  end,
})
