return {
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    keys = {
      {
        "<leader>fw",
        "<cmd>Trouble lsp_references toggle focus=true pinned=true win.position=right<cr>",
        desc = "Find usages (Trouble)",
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "trouble",
        callback = function(event)
          vim.keymap.set("n", "q", "<cmd>Trouble close<cr>", { buffer = event.buf, silent = true })
          vim.keymap.set("n", "<Esc>", "<cmd>Trouble close<cr>", { buffer = event.buf, silent = true })
        end,
      })
    end,
    opts = {
      auto_preview = true,
      focus = true,
      follow = true,
      pinned = true,
      win = {
        type = "split",
        position = "right",
        size = 0.35,
      },
      preview = {
        type = "main",
      },
      modes = {
        lsp_references = {
          title = "Usages",
          focus = true,
          pinned = true,
        },
      },
    },
  },
}
