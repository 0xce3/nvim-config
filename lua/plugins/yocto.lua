return {
  {
    "stevearc/conform.nvim",
    ft = { "yaml" },
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          yaml = { "prettierd", "prettier", stop_after_first = true },
        },
      })
      require("config.yocto").setup_yaml()
    end,
  },
  {
    dir = vim.fn.stdpath("config"),
    name = "yocto-lsp",
    ft = { "bitbake" },
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      require("config.yocto").setup_bitbake()
    end,
  },
}
