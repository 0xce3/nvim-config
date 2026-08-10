return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    cmd = "Yazi",
    init = function()
      vim.env.YAZI_CONFIG_HOME = vim.fs.joinpath(vim.fn.stdpath("config"), "yazi")
    end,
    opts = {
      open_for_directories = false,
      floating_window_border = "rounded",
      open_file_function = function(chosen_file)
        if chosen_file:lower():match("%.pdf$") then
          local opener = vim.fs.joinpath(vim.fn.stdpath("config"), "bin", "nvim-open")
          vim.system({ opener, chosen_file }, { text = true }, function(result)
            if result.code ~= 0 then
              vim.schedule(function()
                vim.notify(vim.trim(result.stderr), vim.log.levels.ERROR, { title = "Open PDF on Windows" })
              end)
            end
          end)
          return
        end
        require("yazi.openers").open_file(chosen_file)
      end,
      keymaps = {
        show_help = "<F1>",
      },
    },
  },
}
