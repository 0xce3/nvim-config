return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      local original_on_attach = opts.on_attach
      opts.on_attach = function(bufnr)
        if original_on_attach then original_on_attach(bufnr) end
        vim.keymap.set("n", "<leader>gl", function()
          require("snacks").lazygit.open()
        end, { buffer = bufnr, desc = "Open lazygit" })
      end
    end,
  },
}
