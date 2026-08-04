-- Colour matching brackets/parentheses/braces by nesting depth
-- (Treesitter-based). Each level cycles through a Gruvbox-toned palette so it
-- blends with the rest of the theme.
--
-- Loaded eagerly (lazy = false): rainbow-delimiters attaches on the FileType
-- event, so if the plugin is lazy-loaded on BufReadPost it misses the buffer
-- that is already open and never highlights it.
return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    lazy = false,
    priority = 900,
    config = function()
      local rainbow = require("rainbow-delimiters")

      local function apply_colors()
        vim.api.nvim_set_hl(0, "RainbowDelimiterRed",    { fg = "#fb4934" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = "#fabd2f" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterBlue",   { fg = "#83a598" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterOrange", { fg = "#fe8019" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterGreen",  { fg = "#b8bb26" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = "#d3869b" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterCyan",   { fg = "#8ec07c" })
      end

      apply_colors()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = apply_colors,
        desc = "Keep rainbow delimiter colours after colorscheme reloads",
      })

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow.strategy["global"],
        },
        query = {
          [""] = "rainbow-delimiters",
        },
        -- Nesting depth cycles through these in order.
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },
}
