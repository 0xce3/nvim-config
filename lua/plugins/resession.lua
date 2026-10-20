return {
  {
    "stevearc/resession.nvim",
    init = function()
      local cwd_before_session_load

      local function reload_blank_file_buffers()
        local reloaded = {}
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if not reloaded[buf] then
              local name = vim.api.nvim_buf_get_name(buf)
              local stat = name ~= "" and vim.uv.fs_stat(name) or nil
              if
                vim.bo[buf].buftype == ""
                and not vim.bo[buf].modified
                and stat
                and stat.type == "file"
                and stat.size > 0
              then
                vim.fn.bufload(buf)
                local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
                if #lines == 1 and lines[1] == "" then
                  reloaded[buf] = true
                  vim.api.nvim_win_call(win, function()
                    -- Resession defers the final :edit until after LoadPost. Force
                    -- a normal buffer read here; a later retry handles remote-UI
                    -- buffer synchronization that completes on the next event loop.
                    vim.cmd("silent! keepjumps edit!")
                  end)
                end
              end
            end
          end
        end
      end

      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          -- Always capture the actual state immediately before :qa. Without
          -- this, <leader>s kept loading an older Last Session indefinitely.
          pcall(function()
            require("resession").save("Last Session", { notify = false })
          end)
        end,
        desc = "Save last session before exit",
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "ResessionLoadPre",
        callback = function()
          cwd_before_session_load = vim.fn.getcwd()
        end,
        desc = "Preserve the launch directory while loading a session",
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "ResessionLoadPost",
        callback = function()
          local workspace = cwd_before_session_load
          cwd_before_session_load = nil
          local remote_workspace = vim.env.NVIM_DEV_WORKSPACE
          if vim.env.NVIM_DEV_REMOTE == "1" and remote_workspace and vim.fn.isdirectory(remote_workspace) == 1 then
            workspace = remote_workspace
          end
          if workspace and vim.fn.isdirectory(workspace) == 1 then
            vim.api.nvim_set_current_dir(workspace)
            vim.cmd.tcd({ args = { workspace } })
          end

          vim.schedule(reload_blank_file_buffers)
          vim.defer_fn(reload_blank_file_buffers, 50)
        end,
        desc = "Finish restoring session file buffers",
      })
    end,
    opts = function(_, opts)
      opts.autosave = {
        enabled = true,
        interval = 60,
        notify = false,
      }
      opts.extensions = opts.extensions or {}
      opts.extensions.task_terminal = { enable_in_tab = true }
    end,
  },
}
