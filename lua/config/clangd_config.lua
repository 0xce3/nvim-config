-- Ensure a global clangd config that strips common cross-compile flags which
-- clang(d) does not understand (e.g. -mfp16-format=ieee, -specs=...). Without
-- this, clangd can report "Unknown argument" diagnostics when pointed at some
-- GCC-generated compile_commands.json files.
--
-- Written to ~/.config/clangd/config.yaml (clangd's global config) — outside any
-- project, so it never pollutes a source repository, and is recreated on
-- startup (so it survives a container rebuild via this nvim config).

local M = {}

local MARKER = "# Managed by nvim (config.clangd_config)"

local CONTENT = MARKER .. [[

# Strip cross-compile flags that clang(d) does not understand.
CompileFlags:
  Remove:
    - -mfp16-format*
    - -mtp=*
    - -specs=*
    - --param*
    - -fno-reorder-functions
    - -fno-defer-pop
    - -fno-printf-return-value
]]

local function config_path()
  local base = vim.env.XDG_CONFIG_HOME
  if not base or base == "" then
    base = vim.fs.joinpath(vim.env.HOME or vim.fn.expand("~"), ".config")
  end
  return vim.fs.joinpath(base, "clangd", "config.yaml")
end

function M.ensure()
  local path = config_path()

  -- Don't clobber a hand-written user config; only manage our own.
  local existing = io.open(path, "r")
  if existing then
    local first = existing:read("*l") or ""
    existing:close()
    if not first:find(MARKER, 1, true) then
      return
    end
  end

  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local out = io.open(path, "w")
  if out then
    out:write(CONTENT)
    out:close()
  end
end

return M
