return {
  {
    "stevearc/resession.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "ResessionLoadPost",
        callback = function()
          local workspace = vim.env.NVIM_DEV_WORKSPACE
          if vim.env.NVIM_DEV_REMOTE == "1" and workspace and vim.fn.isdirectory(workspace) == 1 then
            vim.cmd.cd(workspace)
          end
        end,
        desc = "Keep restored remote sessions in their devcontainer workspace",
      })
    end,
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.task_terminal = { enable_in_tab = true }
    end,
  },
}
