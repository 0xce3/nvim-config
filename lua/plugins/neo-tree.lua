return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    specs = {
      {
        "nvim-mini/mini.icons",
        optional = true,
        opts = {
          file = {
            ["README.md"] = { glyph = "󰈙", hl = "MiniIconsGrey" },
            ["requirements.txt"] = { glyph = "󰈙", hl = "MiniIconsGrey" },
          },
        },
      },
    },
    opts = function(_, opts)
      opts.window = opts.window or {}
      opts.window.mappings = opts.window.mappings or {}
      opts.window.mappings["<Tab>"] = "next_source"
      opts.window.mappings["<S-Tab>"] = "prev_source"
      opts.window.mappings["<leader>tr"] = function() end
      opts.filesystem = vim.tbl_deep_extend("force", opts.filesystem or {}, {
        bind_to_cwd = true,
        follow_current_file = { enabled = true },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      })
      opts.source_selector = vim.tbl_deep_extend("force", opts.source_selector or {}, {
        winbar = false,
        statusline = true,
        separator = "|",
        separator_active = "|",
        highlight_background = "NeoTreeTabInactive",
        highlight_separator = "NeoTreeTabSeparatorInactive",
        highlight_separator_active = "NeoTreeTabSeparatorActive",
      })
    end,
    init = function()
      local function apply_source_tab_colors()
        vim.api.nvim_set_hl(0, "NeoTreeTabInactive", { fg = "#a89984", bg = "#32302f" })
        vim.api.nvim_set_hl(0, "NeoTreeTabActive", { fg = "#ebdbb2", bg = "#32302f", bold = true })
        vim.api.nvim_set_hl(0, "NeoTreeTabSeparatorInactive", { fg = "#7c6f64", bg = "#32302f" })
        vim.api.nvim_set_hl(0, "NeoTreeTabSeparatorActive", { fg = "#a89984", bg = "#32302f" })
         vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = "#ebdbb2", bold = true })
         vim.api.nvim_set_hl(0, "NeoTreeDirectoryIcon", { fg = "#ebdbb2", bold = true })
         vim.api.nvim_set_hl(0, "NeoTreeFileName", { fg = "#bdae93" })
         vim.api.nvim_set_hl(0, "NeoTreeFileNameOpened", { fg = "#d5c4a1" })
        vim.api.nvim_set_hl(0, "NeoTreeGitAdded", { fg = "#b8bb26" })
        vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#b8bb26" })
        vim.api.nvim_set_hl(0, "NeoTreeGitModified", { fg = "#fabd2f" })
        vim.api.nvim_set_hl(0, "NeoTreeGitUnstaged", { fg = "#fabd2f" })
        vim.api.nvim_set_hl(0, "NeoTreeGitDeleted", { fg = "#fb4934" })
        vim.api.nvim_set_hl(0, "NeoTreeGitConflict", { fg = "#fb4934", bold = true })
        vim.api.nvim_set_hl(0, "NeoTreeGitIgnored", { fg = "#928374" })
      end

      apply_source_tab_colors()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() vim.schedule(apply_source_tab_colors) end,
      })
    end,
  },
}
