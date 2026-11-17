-- Run with: nvim --headless -u NONE -i NONE -l tests/lsp_restart_test.lua
local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local spec = dofile(config_root .. "/lua/plugins/lspconfig.lua")
assert(vim.deep_equal(spec.cmd(nil, { "LspInfo" }), { "LspInfo", "LspRestart" }))

local clients, calls, pending, warnings = {}, {}, {}, {}
vim.lsp.config = { clangd = {}, lua_ls = {} }
vim.lsp.get_clients = function(filter)
  return vim.tbl_filter(function(client) return not filter or filter.name == client.name end, clients)
end
vim.lsp.enable = function(name, enabled)
  calls[#calls + 1] = { name, enabled ~= false }
end
vim.defer_fn = function(callback) pending[#pending + 1] = callback end
vim.notify = function(message) warnings[#warnings + 1] = message end

local function client(name)
  return { name = name, stop = function(_, force) calls[#calls + 1] = { name, "stop", force } end }
end

local function restart(command, expected, warning_count)
  calls, pending, warnings = {}, {}, {}
  vim.cmd(command)
  for _, callback in ipairs(pending) do callback() end
  assert(vim.deep_equal(calls, expected), vim.inspect(calls))
  assert(#warnings == (warning_count or 0), vim.inspect(warnings))
end

-- The plugin defines its command before Lazy runs our config callback.
vim.api.nvim_create_user_command("LspRestart", function() error("upstream command was not replaced") end, {})
spec.config()

-- Loading polish afterwards must not replace the corrected command either.
package.loaded["config.clangd_config"] = { ensure = function() end }
package.loaded["config.skeleton"] = { setup = function() end }
dofile(config_root .. "/lua/polish.lua")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved edits" })
local buffer = vim.api.nvim_get_current_buf()
local tick = vim.api.nvim_buf_get_changedtick(buffer)
clients = { client("opencode_ask_cmp"), client("clangd"), client("clangd"), client("lua_ls") }
restart("LspRestart", { { "clangd", false }, { "lua_ls", false }, { "clangd", true }, { "lua_ls", true } })
restart("LspRestart clangd", { { "clangd", false }, { "clangd", true } })
restart("LspRestart! clangd", {
  { "clangd", false }, { "clangd", "stop", true }, { "clangd", "stop", true }, { "clangd", true },
})
assert(vim.deep_equal(vim.fn.getcompletion("LspRestart ", "cmdline"), { "clangd", "lua_ls" }))
assert(vim.deep_equal(vim.fn.getcompletion("LspRestart cl", "cmdline"), { "clangd" }))
restart("LspRestart opencode_ask_cmp", {}, 1)
restart("LspRestart nonexistent", {}, 1)
assert(#pending == 0, "invalid names must not be enabled later")

clients = { client("opencode_ask_cmp") }
restart("LspRestart", {})
assert(#pending == 0, "internal clients must not schedule a restart")
clients = {}
restart("LspRestart", {})
assert(#pending == 0, "no clients must not schedule a restart")
assert(vim.api.nvim_get_current_buf() == buffer, "current buffer must not change")
assert(vim.api.nvim_buf_get_changedtick(buffer) == tick, "buffer text must not change")
assert(vim.bo.modified, "unsaved edits must remain unsaved")
print("lsp_restart_test.lua: ok")
