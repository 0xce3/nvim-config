-- Customize only the statusline tree. Do not modify AstroUI's shared status
-- component defaults because the buffer tabline derives icons from them.
return {
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      local status = require("astroui.status")

      opts.statusline[3] = status.component.file_info {
        file_icon = false,
        filetype = false,
      }
      opts.statusline[9] = status.component.lsp {
        lsp_client_names = {
          mappings = {
            clangd = function()
              local dir = vim.env.NVIM_CLANGD_COMPILE_COMMANDS_DIR
              if not dir or dir == "" then
                local ok, store = pcall(require, "config.clangd_build")
                if ok then dir = store.active(vim.fn.getcwd()) end
              end
              return dir and vim.fn.fnamemodify(dir, ":t") or "clangd"
            end,
          },
        },
      }
      table.insert(opts.statusline, 9, status.component.builder {
        condition = function()
          local terminal = require("config.terminal")
          return terminal.task_status() ~= nil or terminal.is_task_running() or terminal.is_debug_waiting()
        end,
        {
          provider = function()
            return require("astroui").get_icon("Package", 1, true)
          end,
          hl = { fg = "#ebdbb2" },
        },
        {
          provider = function()
            local terminal = require("config.terminal")
            return (terminal.is_debug_waiting() and "DAP: " .. terminal.debug_wait_label() or "Task: " .. (terminal.task_label() or "Task")) .. " "
          end,
          hl = { fg = "#ebdbb2" },
        },
        {
          provider = function()
            local terminal = require("config.terminal")
            if terminal.is_debug_waiting() then return "waiting " .. terminal.task_spinner() end
            local task_status = terminal.task_status()
            if task_status == "success" then return "successful" end
            if task_status == "failed" then return "failed" end
            return "running " .. terminal.task_spinner()
          end,
          hl = function()
            local task_status = require("config.terminal").task_status()
            if task_status == "success" then return { fg = "#b8bb26", bold = true } end
            if task_status == "failed" then return { fg = "#fb4934", bold = true } end
            return { fg = "#fabd2f", bold = true }
          end,
        },
        surround = { separator = "right" },
      })
    end,
  },
}
