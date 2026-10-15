return {
  {
    "stevearc/aerial.nvim",
    opts = function(_, opts)
      -- AstroNvim's bundled on_attach currently passes a legacy `buf` key to
      -- vim.keymap.set through AstroCore. Neovim rejects that option; install
      -- the same buffer-local symbol mappings with the supported `buffer` key.
      opts.on_attach = function(bufnr)
        vim.keymap.set("n", "]y", function() require("aerial").next(vim.v.count1) end, {
          buffer = bufnr,
          desc = "Next symbol",
        })
        vim.keymap.set("n", "[y", function() require("aerial").prev(vim.v.count1) end, {
          buffer = bufnr,
          desc = "Previous symbol",
        })
        vim.keymap.set("n", "]Y", function() require("aerial").next_up(vim.v.count1) end, {
          buffer = bufnr,
          desc = "Next symbol upwards",
        })
        vim.keymap.set("n", "[Y", function() require("aerial").prev_up(vim.v.count1) end, {
          buffer = bufnr,
          desc = "Previous symbol upwards",
        })
      end
    end,
  },
}
