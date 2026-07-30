return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Git diff" },
      {
        "<leader>dm",
        function()
          local path = vim.api.nvim_buf_get_name(0)
          if path == "" or vim.fn.filereadable(path) ~= 1 then
            vim.notify("Current buffer is not a file", vim.log.levels.WARN, { title = "diffview" })
            return
          end
          local dir = vim.fn.fnamemodify(path, ":h")
          local root_result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
          if root_result.code ~= 0 then
            vim.notify("Current file is not in a Git repository", vim.log.levels.WARN, { title = "diffview" })
            return
          end
          local root = vim.trim(root_result.stdout)
          local relative = vim.fs.relpath(root, path)
          if not relative then
            vim.notify("Could not resolve file path relative to Git root", vim.log.levels.WARN, { title = "diffview" })
            return
          end
          local exists = vim.system({ "git", "-C", root, "cat-file", "-e", "main:" .. relative }, { text = true }):wait()
          if exists.code ~= 0 then
            vim.notify("File does not exist on main: " .. relative, vim.log.levels.WARN, { title = "diffview" })
            return
          end
          local line = vim.api.nvim_win_get_cursor(0)[1]
          vim.api.nvim_create_autocmd("User", {
            pattern = "DiffviewViewOpened",
            once = true,
            callback = function()
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buffer = vim.api.nvim_win_get_buf(win)
                local name = vim.api.nvim_buf_get_name(buffer)
                if name:find(relative, 1, true) then
                  vim.api.nvim_win_set_cursor(win, { math.min(line, vim.api.nvim_buf_line_count(buffer)), 0 })
                end
              end
            end,
          })
          vim.cmd("DiffviewOpen main -- " .. vim.fn.fnameescape(relative))
        end,
        desc = "Diff current file against main",
      },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
          winbar_info = true,
        },
        merge_tool = { layout = "diff3_horizontal" },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 34 },
      },
    },
    config = function(_, opts)
      require("diffview").setup(opts)
      vim.api.nvim_create_autocmd("User", {
        pattern = "DiffviewViewOpened",
        callback = function()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local bufnr = vim.api.nvim_win_get_buf(win)
            vim.keymap.set("n", "<Esc>", "<cmd>tabclose<cr>", {
              buffer = bufnr,
              silent = true,
              desc = "Close Diffview tab",
            })
          end
        end,
      })
    end,
  },
}
