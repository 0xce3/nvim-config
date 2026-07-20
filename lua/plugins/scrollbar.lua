return {
  {
    "petertriho/nvim-scrollbar",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "kevinhwang91/nvim-hlslens" },
    opts = {
      handlers = {
        cursor = true,
        diagnostic = true,
        gitsigns = true,
        search = true,
      },
      excluded_filetypes = { "neo-tree" },
    },
  },
}
