-- Highlight printf/scanf format specifiers (%d, %s, %05.2f, %ld, %%, ...) inside
-- C/C++ string literals. Treesitter sees a string as a single node and cannot
-- isolate a substring, so the specifiers are drawn as extmarks on a dedicated
-- namespace at a priority above the Treesitter @string highlight.
--
-- Matches are restricted to characters that actually sit inside a string node,
-- so a modulo expression like `a % b` (or `i % d`) is never coloured.

local M = {}

local ns = vim.api.nvim_create_namespace("printf_format_specifiers")

-- %[argnum$][flags][width][.precision][length]conversion
local pattern = "%%[-+ #0]*%d*%.?%d*[hljztL]*[diouxXeEfFgGaAcspn%%]"

-- Collect the byte ranges of every string literal in the buffer by parsing the
-- Treesitter tree explicitly (do not rely on an attached highlighter).
local function string_ranges(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end
  local trees = parser:parse()
  local lang = parser:lang()
  local query_ok, query = pcall(vim.treesitter.query.parse, lang, "(string_literal) @s")
  if not query_ok then
    return {}
  end

  local ranges = {}
  for _, tree in ipairs(trees) do
    for _, node in query:iter_captures(tree:root(), buf, 0, -1) do
      local sr, sc, er, ec = node:range()
      ranges[#ranges + 1] = { sr, sc, er, ec }
    end
  end
  return ranges
end

local function pos_in_ranges(ranges, row, col)
  for _, r in ipairs(ranges) do
    local after_start = row > r[1] or (row == r[1] and col >= r[2])
    local before_end = row < r[3] or (row == r[3] and col < r[4])
    if after_start and before_end then
      return true
    end
  end
  return false
end

function M.highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local ranges = string_ranges(buf)
  if not ranges then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    local row = i - 1
    local init = 1
    while true do
      local s, e = line:find(pattern, init)
      if not s then
        break
      end
      if pos_in_ranges(ranges, row, s - 1) then
        vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, {
          end_col = e,
          hl_group = "StringFormatSpecifier",
          priority = 200, -- above Treesitter (default 100)
        })
      end
      init = e + 1
    end
  end
end

function M.setup()
  vim.api.nvim_set_hl(0, "StringFormatSpecifier", { fg = "#fe8019", bold = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      vim.api.nvim_set_hl(0, "StringFormatSpecifier", { fg = "#fe8019", bold = true })
    end,
  })

  local group = vim.api.nvim_create_augroup("PrintfFormatSpecifiers", { clear = true })
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
