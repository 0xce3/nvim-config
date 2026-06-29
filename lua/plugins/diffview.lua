-- VS Code "Source Control"-style diff viewer: a file panel on the left and
-- real, fully scrollable diff windows on the right. Navigate files with
-- <Tab>/<S-Tab>, open with <CR>, close the whole view with <leader>gd again
-- (or `q` / :DiffviewClose).
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    keys = {
      {
        "<leader>gd",
        function()
          if next(require("diffview.lib").views) == nil then
            vim.cmd("DiffviewOpen")
          else
            vim.cmd("DiffviewClose")
          end
        end,
        desc = "Toggle Git diff view",
      },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
      { "<leader>gA", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history (all files)" },
    },
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        enhanced_diff_hl = true, -- richer add/change/delete highlighting
        view = {
          default = { winbar_info = true },
          merge_tool = { layout = "diff3_mixed" },
        },
        file_panel = {
          listing_style = "tree",
          win_config = { position = "left", width = 34 },
        },
        keymaps = {
          view = {
            { "n", "<Tab>", actions.select_next_entry, { desc = "Next changed file" } },
            { "n", "<S-Tab>", actions.select_prev_entry, { desc = "Prev changed file" } },
            { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diff view" } },
          },
          file_panel = {
            { "n", "<Tab>", actions.select_next_entry, { desc = "Next changed file" } },
            { "n", "<S-Tab>", actions.select_prev_entry, { desc = "Prev changed file" } },
            { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diff view" } },
          },
        },
      })
    end,
  },
}
