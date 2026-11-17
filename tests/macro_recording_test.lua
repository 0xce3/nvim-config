-- Run with: nvim --headless -u NONE -i NONE -l tests/macro_recording_test.lua
local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))

-- Load the actual mappings without writing clangd configuration or loading plugins.
package.loaded["config.clangd_config"] = { ensure = function() end }
package.loaded["config.skeleton"] = { setup = function() end }
dofile(config_root .. "/lua/polish.lua")

assert(vim.fn.maparg("q", "n") == "<Nop>", "q must not start recording")
local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "unchanged" })
vim.bo.modified = false
local tick = vim.api.nvim_buf_get_changedtick(buffer)

-- Bypassing mappings must not leave a recording active either.
for _, register in ipairs({ "w", "a", "W" }) do
  vim.cmd.normal({ args = { "q" .. register }, bang = true })
  assert(vim.fn.reg_recording() == "", "recording must stop immediately")
end

-- A mapping can bypass the disabled q key as well.
vim.keymap.set("n", "<F6>", "qw", { noremap = true })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F6>", true, false, true), "xt", false)
assert(vim.fn.reg_recording() == "", "mapped recording must stop immediately")
assert(vim.api.nvim_get_current_buf() == buffer, "current buffer must not change")
assert(vim.api.nvim_buf_get_changedtick(buffer) == tick, "buffer text must not change")
assert(not vim.bo.modified, "buffer must remain unmodified")
print("macro_recording_test.lua: ok")
