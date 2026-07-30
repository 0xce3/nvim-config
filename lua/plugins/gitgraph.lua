local function open_popup(opts)
  return Snacks.win(vim.tbl_deep_extend("force", {
    position = "float",
    enter = true,
    width = 0.9,
    height = 0.9,
    border = "rounded",
    title = " Git Graph ",
    title_pos = "center",
    bo = { buftype = "nofile", bufhidden = "wipe", swapfile = false },
    wo = { number = false, relativenumber = false, signcolumn = "no", cursorline = true },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
    },
  }, opts or {}))
end

local function open_commit_diff(commit)
  local win = open_popup({ title = " Commit Diff " })
  win:show()
  local lines = vim.fn.systemlist({ "git", "show", "--color=never", "--format=fuller", commit.hash .. "^!" })
  vim.bo[vim.api.nvim_get_current_buf()].filetype = "diff"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo[vim.api.nvim_get_current_buf()].modifiable = false
end

local function open_git_graph()
  local win = open_popup()
  win:show()
  local lines = vim.fn.systemlist({ "git", "log", "--graph", "--all", "--decorate", "--oneline", "--color=never" })
  vim.bo[vim.api.nvim_get_current_buf()].filetype = "git"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo[vim.api.nvim_get_current_buf()].modifiable = false
end

return {
  {
    "isakbm/gitgraph.nvim",
    opts = function(_, opts)
      opts.hooks = vim.tbl_extend("force", opts.hooks or {}, {
        on_select_commit = open_commit_diff,
      })
    end,
    keys = {
      {
        "<leader>gg",
        function()
          local win = open_popup()
          win:show()
          open_git_graph()
        end,
        desc = "Git graph",
      },
    },
  },
}
