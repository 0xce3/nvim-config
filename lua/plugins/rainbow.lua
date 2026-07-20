return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    lazy = false,
    priority = 900,
    config = function()
      local rainbow = require("rainbow-delimiters")
      local function apply_colors()
        vim.api.nvim_set_hl(0, "RainbowDelimiterRed", { fg = "#fb4934" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = "#fabd2f" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { fg = "#83a598" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterOrange", { fg = "#fe8019" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterGreen", { fg = "#b8bb26" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = "#d3869b" })
        vim.api.nvim_set_hl(0, "RainbowDelimiterCyan", { fg = "#8ec07c" })
      end
      apply_colors()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_colors })
      vim.g.rainbow_delimiters = {
        strategy = { [""] = rainbow.strategy.global },
        query = { [""] = "rainbow-delimiters" },
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
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(event)
          vim.schedule(function() pcall(rainbow.enable, event.buf) end)
        end,
        desc = "Reattach rainbow delimiters when switching buffers",
      })
    end,
  },
}
