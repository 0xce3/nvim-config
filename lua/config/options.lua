vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
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
