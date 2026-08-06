return {
  {
    "stevearc/resession.nvim",
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.task_terminal = { enable_in_tab = true }
    end,
  },
}
