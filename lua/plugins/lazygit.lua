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
        -- LazyGit 0.64 errors when Snacks injects a theme config without a
        -- user config.yml. Keep this portable across fresh installations.
        configure = false,
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
