return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Git diff" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_vertical",
          winbar_info = true,
        },
        merge_tool = { layout = "diff3_vertical" },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 34 },
      },
    },
  },
}
