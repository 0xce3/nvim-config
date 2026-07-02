return {
  {
    "hasansujon786/nvim-navbuddy",
    dependencies = {
      "SmiteshP/nvim-navic",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Navbuddy",
    opts = {
      window = {
        border = "rounded",
        size = { height = "80%", width = "90%" },
        sections = {
          left = { size = "25%" },
          mid = { size = "35%" },
          right = { preview = "leaf" },
        },
      },
      lsp = {
        auto_attach = true,
        preference = { "clangd", "lua_ls" },
      },
      source_buffer = {
        follow_node = true,
        highlight = true,
        reorient = "smart",
      },
    },
  },
}
