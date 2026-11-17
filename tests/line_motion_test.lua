-- Run with: nvim --headless -u NONE -i NONE -l tests/line_motion_test.lua
local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
package.loaded["config.clangd_config"] = { ensure = function() end }
package.loaded["config.skeleton"] = { setup = function() end }
dofile(config_root .. "/lua/polish.lua")

assert(vim.fn.maparg("4", "n") == "$", "4 must map to end of line")
assert(vim.fn.maparg("4", "i") == "", "typing 4 must remain unchanged")
local lines = { "  int value = 4;", "", "text with trailing spaces  " }
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.modified = false
local tick = vim.api.nvim_buf_get_changedtick(0)
for row = 1, #lines do
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.cmd.normal({ args = { "$" }, bang = true })
  local expected = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.cmd.normal({ args = { "4" } })
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), expected), "4 must behave like $")
end
assert(vim.api.nvim_buf_get_changedtick(0) == tick, "movement must not change text")
assert(not vim.bo.modified, "movement must not modify the buffer")
print("line_motion_test.lua: ok")
