vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
-- Full mouse support in Neovim (click files, resize splits,
-- scroll, click to position the cursor). A normal drag now selects text inside
-- Neovim; to use Windows Terminal's own selection (e.g. to copy raw terminal
-- output), hold Shift while dragging. Copying a Neovim selection still works
-- with <C-c> (-> "+ via OSC 52).
opt.mouse = "a"

-- Send explicit yanks to the "+" register to the Windows clipboard via OSC 52
-- (works through terminals that support OSC 52, no clipboard tool
-- needed). Plain y/d/p stay local (Windows-like: only Ctrl+C / "+y copies).
-- Pasting text from Windows into Neovim is done with the terminal's Ctrl+V.
local ok_osc, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok_osc then
  vim.g.clipboard = {
    name = "osc52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = {
      ["+"] = function() return vim.fn.split(vim.fn.getreg("+"), "\n") end,
      ["*"] = function() return vim.fn.split(vim.fn.getreg("*"), "\n") end,
    },
  }
end
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.laststatus = 3
opt.showmode = false
opt.cmdheight = 1
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.pumheight = 12

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.list = true
opt.listchars = { tab = "  ", trail = ".", nbsp = "+" }

opt.hidden = true

-- Folding driven by Treesitter (functions, blocks, structs, ...). Files open
-- fully unfolded (foldlevel 99); use zc/zo/za to fold on demand, zR/zM to
-- open/close all. Falls back to indent folding for buffers without a parser.
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldnestmax = 6
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- Show a fold gutter with open/closed chevrons so it's obvious which lines are
-- foldable and whether they're open or closed.
opt.foldcolumn = "1"
opt.fillchars:append({
  fold = " ",
  foldopen = "▾",  -- open fold
  foldclose = "▸", -- closed fold
  foldsep = " ",
})

-- Closed folds show the full signature (joining the next lines when the return
-- type sits on its own line, so the function name is always visible) plus a
-- "(N lines)" count.
function _G.fold_text()
  local fs, fe = vim.v.foldstart, vim.v.foldend
  local text = vim.fn.getline(fs)
  -- Pull in following lines until the "(" appears, so a return type on its own
  -- line still shows the function name. Cap the lookahead at a few lines.
  if not text:find("%(") then
    for lnum = fs + 1, math.min(fe, fs + 3) do
      local l = vim.fn.getline(lnum)
      text = text .. " " .. vim.trim(l)
      if l:find("%(") then
        break
      end
    end
  end
  text = text:gsub("\t", string.rep(" ", vim.bo.tabstop))
  return text .. "   (" .. (fe - fs + 1) .. " lines)"
end
opt.foldtext = "v:lua.fold_text()"

-- Use indent-based folding only where Treesitter has no parser, so zc/zo still
-- work in plain text / config files.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local ok = pcall(vim.treesitter.get_parser, args.buf)
    if not ok then
      vim.opt_local.foldmethod = "indent"
    end
  end,
})

-- bash -ic: interactive flag makes $- contain 'i', so ~/.bashrc runs fully
-- (the default .bashrc guard "case $- in *i*)" requires this)
opt.shell = "bash"
opt.shellcmdflag = "-ic"

vim.cmd("syntax enable")
vim.cmd("filetype plugin indent on")

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})

vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, {
      focusable = false,
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
      border = "rounded",
      source = "always",
      scope = "cursor",
    })
  end,
})
