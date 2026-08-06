return {
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    cmd = "Yazi",
    opts = {
      open_for_directories = false,
      floating_window_border = "rounded",
      keymaps = {
        show_help = "<F1>",
      },
    },
  },
}
