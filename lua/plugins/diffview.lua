local previous_showtabline

local function hide_tabline()
  previous_showtabline = vim.o.showtabline
  vim.o.showtabline = 0
end

local function restore_tabline()
  if previous_showtabline ~= nil then
    vim.o.showtabline = previous_showtabline
    previous_showtabline = nil
  end
end

local function close_diffview()
  pcall(vim.cmd, "DiffviewClose")
  restore_tabline()
  vim.schedule(function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    if #wins == 1 then
      local buf = vim.api.nvim_win_get_buf(wins[1])
      if vim.api.nvim_buf_get_name(buf) == "" and vim.api.nvim_buf_line_count(buf) <= 1 then
        pcall(vim.cmd, "tabclose")
      end
    end
  end)
end

-- VS Code "Source Control"-style diff viewer in a separate Neovim tab,
-- so normal buffer/window layout is never disturbed by buffer switches.
-- Navigate files with <Tab>/<S-Tab>, close with <leader>gd or `q`.
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    keys = {
      {
        "<leader>gd",
        function()
          local views = require("diffview.lib").views
          if next(views) == nil then
            hide_tabline()
            vim.cmd("tabnew")
            local empty_buf = vim.api.nvim_get_current_buf()
            vim.bo[empty_buf].bufhidden = "wipe"
            vim.cmd("DiffviewOpen")
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(empty_buf) and vim.api.nvim_buf_get_name(empty_buf) == "" then
                pcall(vim.api.nvim_buf_delete, empty_buf, { force = true })
              end
            end)
          else
            close_diffview()
          end
        end,
        desc = "Toggle Git diff view (new tab)",
      },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
      { "<leader>gA", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history (all files)" },
    },
    config = function()
      local actions = require("diffview.actions")
      local function block_buffer_switch()
        vim.notify("Close Diffview before switching buffers", vim.log.levels.WARN, { title = "diffview" })
      end
      local view_keymaps = {
        { "n", "<Tab>", actions.select_next_entry, { desc = "Next changed file" } },
        { "n", "<S-Tab>", actions.select_prev_entry, { desc = "Prev changed file" } },
        { "n", "q", close_diffview, { desc = "Close diff view" } },
      }
      local file_panel_keymaps = vim.deepcopy(view_keymaps)
      for i = 1, 9 do
        table.insert(view_keymaps, { "n", "<leader>" .. i, block_buffer_switch, { desc = "Blocked in Diffview" } })
        table.insert(file_panel_keymaps, { "n", "<leader>" .. i, block_buffer_switch, { desc = "Blocked in Diffview" } })
      end

      require("diffview").setup({
        enhanced_diff_hl = true,
        view = {
          default = { winbar_info = true },
          merge_tool = { layout = "diff3_mixed" },
        },
        file_panel = {
          listing_style = "tree",
          win_config = { position = "left", width = 34 },
        },
        keymaps = {
          view = view_keymaps,
          file_panel = file_panel_keymaps,
        },
      })
    end,
  },
}
