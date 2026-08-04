-- Reuse the established VS Code task integration while AstroNvim owns the
-- plugin manager and the surrounding editor defaults.
local legacy_specs = dofile(vim.fn.stdpath("config") .. "/lua/legacy_plugins/init.lua")

for _, spec in ipairs(legacy_specs) do
  if type(spec) == "table" and spec[1] == "EthanJWright/vs-tasks.nvim" then
    return spec
  end
end

return {}
