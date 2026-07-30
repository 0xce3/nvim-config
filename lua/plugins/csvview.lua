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
      local function has_conflict_markers(bufnr)
        for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
          if line:match("^<<<<<<<") or line:match("^=======") or line:match("^>>>>>>>") then return true end
        end
        return false
      end
      local function refresh_csvview(bufnr)
        if has_conflict_markers(bufnr) then
          pcall(csvview.disable, bufnr)
          return
        end
        local delimiter = vim.b[bufnr].csv_delimiter or ","
        csvview.enable(bufnr, {
          parser = { delimiter = delimiter },
          view = { display_mode = "border", header_lnum = 1, sticky_header = { enabled = true } },
        })
      end
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "csv",
        callback = function(args)
          pcall(csvview.disable, args.buf)
          vim.keymap.set("n", "<leader>cv", function()
            csvview.toggle(args.buf, {
              parser = { delimiter = vim.b[args.buf].csv_delimiter or "," },
              view = { display_mode = "border", header_lnum = 1, sticky_header = { enabled = true } },
            })
          end, { buffer = args.buf, silent = true, desc = "Toggle CSV table view" })
        end,
        desc = "Keep CSV files editable as plain text",
      })
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.csv",
        callback = function(args) pcall(csvview.disable, args.buf) end,
        desc = "Keep CSV view disabled",
      })
      vim.api.nvim_create_autocmd("InsertEnter", {
        pattern = "*.csv",
        callback = function(args) pcall(csvview.disable, args.buf) end,
        desc = "Disable CSV view while editing",
      })
      vim.api.nvim_create_autocmd("InsertLeave", {
        pattern = "*.csv",
        callback = function(args) pcall(csvview.disable, args.buf) end,
        desc = "Keep CSV view disabled after editing",
      })
      if vim.bo.filetype == "csv" then pcall(csvview.disable, 0) end
    end,
  },
}
