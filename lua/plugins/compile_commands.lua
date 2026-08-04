-- Restore the project compile_commands.json picker from the previous config.
local spec = dofile(vim.fn.stdpath("config") .. "/lua/legacy_plugins/compile_commands.lua")
spec.dependencies = {
  "nvim-lua/plenary.nvim",
}

for index, key in ipairs(spec.keys or {}) do
  if key[1] == "<leader>fc" then
    spec.keys[index] = {
      "<leader>lc",
      key[2],
      desc = "Switch clangd build (compile_commands)",
    }
  end
end

return spec
