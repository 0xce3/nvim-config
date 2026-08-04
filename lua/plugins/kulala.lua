return {
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>rw", function() require("config.kulala_workspace").open() end, desc = "Open Kulala workspace" },
      { "<leader>rn", function() require("config.kulala_workspace").new() end, desc = "New Kulala workspace" },
      { "<leader>rf", function() require("config.kulala_workspace").pick_request() end, desc = "Find Kulala request" },
    },
  },
}
