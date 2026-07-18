-- Request clangd's non-standard inactive preprocessor ranges and render them
-- above Treesitter and semantic-token highlights.
local M = {}

local ns = vim.api.nvim_create_namespace("clangd_inactive_regions")

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.inactiveRegionsCapabilities = { inactiveRegions = true }
  return capabilities
end

local function apply_regions(params)
  local document = params.textDocument or {}
  local uri = document.uri or params.uri
  if not uri then
    return
  end

  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, region in ipairs(params.regions or params.inactiveRegions or {}) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, region.start.line, region.start.character, {
      end_row = region["end"].line,
      end_col = region["end"].character,
      hl_group = "ClangdInactiveCode",
      priority = 150,
    })
  end
end

function M.setup()
  local function colors()
    vim.api.nvim_set_hl(0, "ClangdInactiveCode", { fg = "#665c54" })
  end
  colors()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

  vim.lsp.handlers["textDocument/inactiveRegions"] = function(_, params)
    apply_regions(params)
  end
end

return M
