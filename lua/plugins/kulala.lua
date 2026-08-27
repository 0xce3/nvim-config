return {
  {
    "mistweaverco/kulala.nvim",
    lazy = false,
    keys = {
      { "<leader>rr", function() require("kulala").run() end, desc = "Run request under cursor" },
      { "<leader>ra", function() require("kulala").run_all() end, desc = "Run all requests" },
      { "<leader>rs", function() require("kulala").scratchpad() end, desc = "Open scratchpad" },
      { "<leader>rc", function() require("kulala").copy() end, desc = "Copy as cURL" },
      { "<leader>rw", function() require("config.kulala_workspace").open() end, desc = "Open Kulala workspace" },
      { "<leader>rn", function() require("config.kulala_workspace").new() end, desc = "New Kulala workspace" },
      { "<leader>rf", function() require("config.kulala_workspace").pick_request() end, desc = "Find Kulala request" },
      {
        "<Esc>",
        function()
          pcall(require("kulala.cmd.kulala_core_bridge").interrupt_active)
          vim.cmd("nohlsearch")
        end,
        desc = "Cancel running request",
        mode = "n",
      },
    },
  },
}
