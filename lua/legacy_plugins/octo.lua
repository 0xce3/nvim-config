-- GitHub PRs & issues inside Neovim, incl. inline review comments on the diff.
-- Complements lazygit (which only does local Git, no GitHub review threads).
-- Requires the `gh` CLI to be installed and authenticated.
--
-- Typical review flow:
--   <leader>pr   list PRs -> <CR> opens the PR (conversation + review comments)
--   <leader>prr  start a review -> opens the diff with inline comment threads
--   ]t / [t      jump to next / previous comment thread (in a review diff)
--   <space>ca    add a comment on the current line / selection
--   <leader>prs  submit the review
return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      { "<leader>pr", "<cmd>Octo pr list<cr>", desc = "List PRs" },
      { "<leader>prc", "<cmd>Octo pr create<cr>", desc = "Create PR" },
      { "<leader>prr", "<cmd>Octo review start<cr>", desc = "Start PR review" },
      { "<leader>prR", "<cmd>Octo review resume<cr>", desc = "Resume PR review" },
      { "<leader>prs", "<cmd>Octo review submit<cr>", desc = "Submit PR review" },
      { "<leader>pi", "<cmd>Octo issue list<cr>", desc = "List issues" },
    },
    opts = {
      use_local_fs = true,
      -- Show review comment threads inline on the diff.
      ui = { use_signcolumn = true },
      mappings = {
        review_diff = {
          add_review_comment = { lhs = "<space>ca", desc = "add comment" },
          add_review_suggestion = { lhs = "<space>sa", desc = "add suggestion" },
          next_thread = { lhs = "]t", desc = "next comment thread" },
          prev_thread = { lhs = "[t", desc = "prev comment thread" },
          select_next_entry = { lhs = "<Tab>", desc = "next changed file" },
          select_prev_entry = { lhs = "<S-Tab>", desc = "prev changed file" },
          close_review_tab = { lhs = "<C-c>", desc = "close review" },
        },
      },
    },
  },
}
