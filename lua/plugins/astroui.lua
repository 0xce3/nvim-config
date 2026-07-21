-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
local function project_header()
  local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
  local project = vim.fs.basename(root or vim.uv.cwd())
  local files = vim.fn.systemlist({ "git", "-C", root, "ls-files" })
  local languages = {}
  local seen = {}
  local extensions = {
    [".c"] = "C",
    [".h"] = "C/C++",
    [".cpp"] = "C++",
    [".hpp"] = "C++",
    [".lua"] = "Lua",
    [".py"] = "Python",
    [".rs"] = "Rust",
    [".js"] = "JavaScript",
    [".ts"] = "TypeScript",
    [".yaml"] = "YAML",
    [".yml"] = "YAML",
  }

  for _, file in ipairs(files) do
    local extension = file:match("(%.[^./]+)$")
    local language = extensions[extension]
    if language and not seen[language] then
      seen[language] = true
      languages[#languages + 1] = language
    end
  end
  table.sort(languages)

  local branch = vim.fn.systemlist({ "git", "-C", root, "branch", "--show-current" })[1] or ""
  local status = vim.fn.systemlist({ "git", "-C", root, "status", "--short" })
  local state = #status == 0 and "clean" or (#status .. " changed")
  local language_text = #languages > 0 and table.concat(languages, ", ") or "unknown"

  return table.concat({
    "  ██████   █████ █████   █████ █████ ██████   ██████",
    "  ▒▒██████ ▒▒███ ▒▒███   ▒▒███ ▒▒███ ▒▒██████ ██████ ",
    "   ▒███▒███ ▒███  ▒███    ▒███  ▒███  ▒███▒█████▒███ ",
    "   ▒███▒▒███▒███  ▒███    ▒███  ▒███  ▒███▒▒███ ▒███ ",
    "   ▒███ ▒▒██████  ▒▒███   ███   ▒███  ▒███ ▒▒▒  ▒███ ",
    "   ▒███  ▒▒█████   ▒▒▒█████▒    ▒███  ▒███      ▒███ ",
    "   █████  ▒▒█████    ▒▒███      █████ █████     █████",
    "  ▒▒▒▒▒    ▒▒▒▒▒      ▒▒▒      ▒▒▒▒▒ ▒▒▒▒▒     ▒▒▒▒▒ ",
    "",
    "  +------------------------------------------------------------+",
    "  |  PROJECT   " .. project .. string.rep(" ", math.max(1, 42 - #project)) .. "|",
    "  |  BRANCH    " .. (branch ~= "" and branch or "detached HEAD") .. string.rep(" ", math.max(1, 42 - #(branch ~= "" and branch or "detached HEAD"))) .. "|",
    "  |  STATUS    " .. state .. string.rep(" ", math.max(1, 42 - #state)) .. "|",
    "  |  LANGUAGES " .. language_text .. string.rep(" ", math.max(1, 42 - #language_text)) .. "|",
    "  +------------------------------------------------------------+",
  }, "\n")
end

return {
  {
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
        TabLine = { bg = "#32302f", fg = "#a89984" },
        TabLineFill = { bg = "#32302f", fg = "#a89984" },
        TabLineSel = { bg = "#32302f", fg = "#ebdbb2", bold = true },
        FoldColumn = { bg = "NONE" },
        SignColumn = { bg = "NONE" },
        CursorLineSign = { bg = "NONE" },
      },
    },
      status = {
        colors = {
          git_branch_fg = "#d3869b",
        },
        winbar = {
          enabled = {},
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
  },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = project_header(),
        },
        sections = {
          { section = "header", align = "left", indent = 4, padding = 5 },
          { section = "keys", gap = 1, padding = 3 },
          { section = "startup" },
        },
      },
    },
  },
}
