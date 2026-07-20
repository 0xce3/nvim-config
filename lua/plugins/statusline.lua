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
    end,
  },
}
