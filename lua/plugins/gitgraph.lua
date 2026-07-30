return {
  {
    "isakbm/gitgraph.nvim",
    keys = {
      {
        "<leader>gG",
        function() require("gitgraph").draw({}, { all = true, max_count = 5000 }) end,
        desc = "Git graph",
      },
    },
  },
}
