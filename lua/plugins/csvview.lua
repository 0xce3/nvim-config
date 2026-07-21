return {
  {
    "hat0uma/csvview.nvim",
    ft = "csv",
    opts = {
      view = {
        display_mode = "border",
      },
    },
    config = function(_, opts)
      local csvview = require("csvview")
      csvview.setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "csv",
        callback = function(args)
          local delimiter = vim.b[args.buf].csv_delimiter or ","
          csvview.enable(args.buf, {
            parser = { delimiter = delimiter },
            view = {
              display_mode = "border",
              header_lnum = 1,
              sticky_header = { enabled = true },
            },
          })
        end,
        desc = "Enable CSV table view",
      })
      if vim.bo.filetype == "csv" then
        local delimiter = vim.b.csv_delimiter or ","
        csvview.enable(0, {
          parser = { delimiter = delimiter },
          view = {
            display_mode = "border",
            header_lnum = 1,
            sticky_header = { enabled = true },
          },
        })
      end
    end,
  },
}
