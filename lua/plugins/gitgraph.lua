return {
  {
    "isakbm/gitgraph.nvim",
    opts = function(_, opts)
      opts.hooks = vim.tbl_extend("force", opts.hooks or {}, {
        on_select_commit = function(commit) vim.cmd("DiffviewOpen " .. commit.hash .. "^!") end,
      })
    end,
    keys = {
      {
        "<leader>gg",
        function() require("gitgraph").draw({}, { all = true, max_count = 5000 }) end,
        desc = "Git graph",
      },
    },
  },
}
