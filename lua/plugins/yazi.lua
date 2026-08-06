return {
  {
    "nvim-mini/mini.icons",
    optional = true,
    opts = {
      file = {
        Yazi = { glyph = "", hl = "MiniIconsYellow" },
      },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    cmd = "Yazi",
    init = function()
      vim.env.YAZI_CONFIG_HOME = vim.fs.joinpath(vim.fn.stdpath("config"), "yazi")
    end,
    opts = {
      open_for_directories = false,
      floating_window_border = "rounded",
      keymaps = {
        show_help = "<F1>",
      },
    },
  },
}
