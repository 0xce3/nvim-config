require("config.options")
require("config.keymaps")
require("config.filetypes")
require("config.format_specifiers").setup()
require("config.preproc").setup()
require("config.lazy")

-- Warm container/devcontainer cache in the background after UI renders.
-- This avoids blocking startup with docker/fd calls (which have timeouts
-- but still cause a visible freeze when called synchronously).
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      pcall(require("config.container_detect").refresh_cache)
    end)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if vim.fn.argc(-1) ~= 0 then
      return
    end
    vim.schedule(function()
      vim.defer_fn(function()
        local bufs = vim.api.nvim_list_bufs()
        local has_real_buffers = false
        for _, buf in ipairs(bufs) do
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
            and vim.bo[buf].buftype ~= "terminal"
            and vim.api.nvim_buf_get_name(buf) ~= "" then
            has_real_buffers = true
            break
          end
        end
        if not has_real_buffers then
          require("config.workspace_hub").open()
        end
      end, 100)
    end)
  end,
})
