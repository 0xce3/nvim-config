-- Grey out the leading '#' of every C/C++ preprocessor directive
-- (#include, #define, #if, #endif, ...). Treesitter colours the '#' and the
-- directive keyword as a single token, so the '#' can't be split off by a
-- highlight group alone; this paints just that one character via an extmark at
-- a priority above Treesitter / clangd.

local M = {}

local ns = vim.api.nvim_create_namespace("preproc_hash")

function M.highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    -- First non-blank character is '#': it starts a preprocessor directive.
    local indent = line:match("^(%s*)#")
    if indent then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #indent, {
        end_col = #indent + 1,
        hl_group = "PreprocHash",
        priority = 200, -- above Treesitter (100) and clangd (125)
      })
    end
  end
end

function M.setup()
  local function colors()
    vim.api.nvim_set_hl(0, "PreprocHash", { fg = "#928374" }) -- gruvbox gray
  end
  colors()
  vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = colors })

  local group = vim.api.nvim_create_augroup("PreprocHash", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = { "*.c", "*.h", "*.cpp", "*.hpp", "*.cc", "*.cxx" },
    callback = function(args)
      vim.schedule(function()
        M.highlight(args.buf)
      end)
    end,
  })
end

return M
