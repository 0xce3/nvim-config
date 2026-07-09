-- fzf-lua: the day-to-day fuzzy finder (files / live grep / word under cursor /
-- buffers / symbols). Faster than Telescope on large repos. Telescope stays
-- installed only as a library for vs-tasks and the <leader>fc build switcher.
local function workspace_root()
  return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
end

return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      { "<C-p>",      function() require("fzf-lua").files() end,                desc = "Find files" },
      { "<leader>ff", function() require("fzf-lua").files() end,                desc = "Find files" },
      { "<leader>fg", function() require("fzf-lua").live_grep() end,            desc = "Live grep" },
      {
        "<leader>fw",
        function()
          local root = vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
          require("fzf-lua").grep_visual({ cwd = root })
        end,
        mode = "x",
        desc = "Grep selection (workspace)",
      },
      { "<leader>fb", function() require("telescope.builtin").buffers() end,    desc = "Find buffers" },
      { "<leader>fh", function() require("fzf-lua").helptags() end,             desc = "Help tags" },
      { "<leader>fr", function() require("fzf-lua").oldfiles() end,             desc = "Recent files" },
      { "<leader>fs", function() require("fzf-lua").lsp_document_symbols() end, desc = "Document symbols" },
      { "<leader>fG", function() require("fzf-lua").grep_project() end,         desc = "Grep project (all lines)" },
      { "<leader>fz", function() require("fzf-lua").resume() end,               desc = "Resume last search" },
      { "<leader>gs", function() require("fzf-lua").git_status() end,           desc = "Git status (changed files)" },
    },
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({
        "default",
        winopts = {
          height = 0.85,
          width = 0.85,
          row = 0.35,
          col = 0.50,
          border = "rounded",
          preview = {
            layout = "horizontal",
            horizontal = "right:55%",
            scrollbar = "float",
          },
        },
        -- Map the fzf pane colours to the active colorscheme (Gruvbox Soft Dark).
        fzf_colors = {
          ["fg"]      = { "fg", "Normal" },
          ["bg"]      = { "bg", "Normal" },
          ["hl"]      = { "fg", "Comment" },
          ["fg+"]     = { "fg", "Normal" },
          ["bg+"]     = { "bg", "CursorLine" },
          ["hl+"]     = { "fg", "Statement" },
          ["info"]    = { "fg", "PreProc" },
          ["prompt"]  = { "fg", "Conditional" },
          ["pointer"] = { "fg", "Exception" },
          ["marker"]  = { "fg", "Keyword" },
          ["spinner"] = { "fg", "Label" },
          ["header"]  = { "fg", "Comment" },
          ["gutter"]  = "-1",
        },
        keymap = {
          builtin = {
            ["<C-d>"] = "preview-page-down",
            ["<C-u>"] = "preview-page-up",
            ["<C-k>"] = "yank",
          },
          fzf = {
            ["ctrl-q"] = "select-all+accept", -- send all matches to quickfix
          },
        },
      })
    end,
  },
}
