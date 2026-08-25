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

          vim.schedule(function()
            for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local buf = vim.api.nvim_win_get_buf(win)
                local name = vim.api.nvim_buf_get_name(buf)
                local stat = name ~= "" and vim.uv.fs_stat(name) or nil
                local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
                local is_blank = #lines == 1 and lines[1] == ""

                if
                  vim.bo[buf].buftype == ""
                  and stat
                  and stat.type == "file"
                  and stat.size > 0
                  and is_blank
                then
                  vim.api.nvim_win_call(win, function() pcall(vim.cmd, "silent edit!") end)
                end
              end
            end
          end)
        end,
        desc = "Finish restoring session file buffers",
      })
    end,
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.task_terminal = { enable_in_tab = true }
    end,
  },
}
