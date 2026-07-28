return {
  {
    "folke/snacks.nvim",
    opts = {
      win = {
        keys = {
          q = "close",
        },
      },
      lazygit = {
        enabled = true,
        win = {
          style = "lazygit",
          border = "rounded",
          width = 0.85,
          height = 0.85,
          keys = { term_normal = false },
        },
      },
    },
  },
}
