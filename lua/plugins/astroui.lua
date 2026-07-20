-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astroui",
  init = function()
    vim.api.nvim_create_autocmd({ "BufModifiedSet", "DiagnosticChanged" }, {
      callback = function() vim.schedule(function() vim.cmd.redrawtabline() end) end,
      desc = "Refresh tabline buffer state",
    })
  end,
  ---@type AstroUIOpts
  opts = {
    -- change colorscheme
    colorscheme = "gruvbox",
    highlights = {
      init = {
        StatusLine = { bg = "#282828", fg = "#ebdbb2" },
        StatusLineNC = { bg = "#282828", fg = "#a89984" },
      },
    },
    status = {
      colors = {
        git_branch_fg = "#d3869b",
      },
      components = {
        tabline_file_info = {
          hl = function(self)
            local error_count = #vim.diagnostic.get(self.bufnr, {
              severity = vim.diagnostic.severity.ERROR,
            })
            if error_count > 0 then return { fg = "#fb4934", bold = true } end
            if vim.bo[self.bufnr].modified then return { fg = "#fe8019", bold = true } end
            return require("astroui.status.hl").get_attributes(self.tab_type)
          end,
        },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      -- configure the loading of the lsp in the status line
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
