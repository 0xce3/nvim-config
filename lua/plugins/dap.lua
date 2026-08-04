return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        opts = { ensure_installed = { "cpptools" } },
      },
    },
    lazy = false,
    config = function()
      require("nvim-dap-virtual-text").setup()
      require("config.vscode_debug").setup()
    end,
  },
}
