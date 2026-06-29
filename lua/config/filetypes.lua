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
  },
})

-- Lightweight syntax for CONFIG_*=value fragment files.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "kconf",
  callback = function()
    vim.bo.commentstring = "# %s"
    vim.bo.comments = ":#"
    vim.cmd([[
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
    ]])
  end,
})
