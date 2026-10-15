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
    vim.api.nvim_create_autocmd("BufModifiedSet", {
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
        TabLine = { bg = "#32302f", fg = "#ebdbb2" },
        TabLineFill = { bg = "#32302f", fg = "#a89984" },
        TabLineSel = { bg = "#3c3836", fg = "#ebdbb2", bold = true },
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
          file_icon = {
            hl = function(self)
              local attributes = require("astroui.status.hl").file_icon("tabline")(self)
              if self.tab_type == "buffer_active" then
                attributes.bg = "#3c3836"
                attributes.underline = true
                attributes.sp = "#ebdbb2"
              end
              attributes.fg = "#ebdbb2"
              return attributes
            end,
          },
          hl = function(self)
            local active = self.tab_type == "buffer_active"
            local attributes = require("astroui.status.hl").get_attributes(self.tab_type)
            if active then
              attributes.bg = "#3c3836"
              attributes.underline = true
              attributes.sp = "#ebdbb2"
            end
            attributes.fg = "#ebdbb2"
            attributes.bold = false
            return attributes
          end,
          close_button = {
            hl = function(self)
              local attributes = require("astroui.status.hl").get_attributes(self.tab_type .. "_close")
              attributes.fg = "#ebdbb2"
              return attributes
            end,
          },
        },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      Local = "",
      Remote = "",
      Ports = "󰑩",
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
