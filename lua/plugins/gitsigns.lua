return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      opts.on_attach = function(bufnr)
        -- AstroNvim's bundled Gitsigns mapping callback currently forwards
        -- the legacy `buf` key to vim.keymap.set during session restore.
        -- Keep Gitsigns attached and define the local mapping directly.
        vim.keymap.set("n", "<leader>gl", function()
          require("config.lazygit").open_window()
        end, { buffer = bufnr, desc = "Open lazygit buffer" })
      end
    end,
  },
}
