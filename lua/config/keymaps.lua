local map = vim.keymap.set

local function is_replacement_buffer(bufnr, current)
  if bufnr == current or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted or vim.bo[bufnr].filetype == "neo-tree" then
    return false
  end

  return vim.bo[bufnr].buftype ~= "nofile"
end

local function replacement_buffer(current)
  local alternate = vim.fn.bufnr("#")
  if is_replacement_buffer(alternate, current) then
    return alternate
  end

  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(buffers, function(left, right)
    return (left.lastused or 0) > (right.lastused or 0)
  end)

  for _, buffer in ipairs(buffers) do
    if is_replacement_buffer(buffer.bufnr, current) then
      return buffer.bufnr
    end
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].swapfile = false
  return scratch
end

local function windows_showing_buffer(bufnr)
  local windows = {}

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_get_config(win).relative == "" and vim.api.nvim_win_get_buf(win) == bufnr then
        table.insert(windows, win)
      end
    end
  end

  return windows
end

local function close_current_buffer(force)
  local current = vim.api.nvim_get_current_buf()

  if vim.bo[current].filetype == "neo-tree" then
    vim.notify("Neo-tree mit <leader>E schliessen.", vim.log.levels.INFO)
    return
  end

  if vim.bo[current].modified and not force then
    vim.notify("Buffer hat ungespeicherte Aenderungen. Nutze :BufferClose! oder <leader>X.", vim.log.levels.WARN)
    return
  end

  local replacement = replacement_buffer(current)
  for _, win in ipairs(windows_showing_buffer(current)) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_buf(win, replacement)
    end
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, current, { force = force })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("BufferClose", function(opts)
  close_current_buffer(opts.bang)
end, { bang = true, desc = "Close current buffer without closing the editor layout" })

vim.api.nvim_create_user_command("Bd", function(opts)
  close_current_buffer(opts.bang)
end, { bang = true, desc = "Close current buffer without closing the editor layout" })

local function clang_format_buffer(bufnr)
  if vim.fn.executable("clang-format") == 0 then
    return false
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  if vim.bo[bufnr].endofline then
    input = input .. "\n"
  end

  local result = vim.system({ "clang-format", "--assume-filename", filename }, {
    stdin = input,
    text = true,
  }):wait()

  if result.code ~= 0 then
    vim.notify(result.stderr ~= "" and result.stderr or "clang-format failed", vim.log.levels.WARN)
    return false
  end

  local output = vim.split(result.stdout:gsub("\n$", ""), "\n", { plain = true })
  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
  vim.fn.winrestview(view)
  return true
end

local function format_buffer(bufnr)
  if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == "c" or filetype == "cpp" or filetype == "h" or filetype == "hpp" then
    if clang_format_buffer(bufnr) then
      return
    end
  end

  local has_formatter = false
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method("textDocument/formatting", bufnr) then
      has_formatter = true
      break
    end
  end

  if not has_formatter then
    return
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = false,
    timeout_ms = 2000,
  })
end

vim.api.nvim_create_user_command("Format", function()
  format_buffer(vim.api.nvim_get_current_buf())
end, { desc = "Format current buffer" })

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(event)
    format_buffer(event.buf)
  end,
  desc = "Format buffer before saving",
})

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>x", "<cmd>BufferClose<cr>", { desc = "Close buffer" })
map("n", "<leader>X", "<cmd>BufferClose!<cr>", { desc = "Force close buffer" })

map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })
map("n", "<leader>gg", "<cmd>Git<cr>", { desc = "Open Git status" })
map("n", "K", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>dp", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "<leader>dn", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostics list" })

-- Git hunk navigation (replaces [c/]c for German keyboard)
map("n", "<leader>gn", function() require("gitsigns").next_hunk() end, { desc = "Next git hunk" })
map("n", "<leader>gp", function() require("gitsigns").prev_hunk() end, { desc = "Prev git hunk" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = function(desc)
      return { buffer = event.buf, desc = desc }
    end

    map("n", "gd", vim.lsp.buf.definition, opts("Go to definition"))
    map("n", "gD", vim.lsp.buf.declaration, opts("Go to declaration"))
    map("n", "gi", vim.lsp.buf.implementation, opts("Go to implementation"))
    map("n", "gr", vim.lsp.buf.references, opts("Go to references"))
    map("n", "gh", vim.lsp.buf.hover, opts("Show hover documentation"))
    map("n", "<leader>lr", vim.lsp.buf.rename, opts("Rename symbol"))
    map("n", "<leader>la", vim.lsp.buf.code_action, opts("Code action"))
  end,
})

-- Buffer navigation
for i = 1, 9 do
  map("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", { desc = "Go to buffer " .. i })
end

map("n", "<F12>", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
map("t", "<F12>", [[<cmd>ToggleTerm<cr>]], { desc = "Toggle terminal" })

-- Octo review file navigation (only in octo buffers)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "octo",
  callback = function()
    map("n", "<C-j>", "]q", { buffer = true, desc = "Next changed file" })
    map("n", "<C-k>", "[q", { buffer = true, desc = "Prev changed file" })
  end,
})

map("t", "<c-z>", [[<c-\><c-n>u]], { desc = "Undo in editor" })
map("t", "<esc><esc>", [[<c-\><c-n>]], { desc = "Leave terminal mode" })
map("t", "<c-h>", [[<cmd>wincmd h<cr>]], { desc = "Move left" })
map("t", "<c-j>", [[<cmd>wincmd j<cr>]], { desc = "Move down" })
map("t", "<c-k>", [[<cmd>wincmd k<cr>]], { desc = "Move up" })
map("t", "<c-l>", [[<cmd>wincmd l<cr>]], { desc = "Move right" })

map("n", "<c-h>", "<cmd>wincmd h<cr>", { desc = "Move left" })
map("n", "<c-j>", "<cmd>wincmd j<cr>", { desc = "Move down" })
map("n", "<c-k>", "<cmd>wincmd k<cr>", { desc = "Move up" })
map("n", "<c-l>", "<cmd>wincmd l<cr>", { desc = "Move right" })
map("n", "<leader>wh", "<cmd>wincmd h<cr>", { desc = "Move left" })
map("n", "<leader>wl", "<cmd>wincmd l<cr>", { desc = "Move right" })
map("n", "<leader>wj", "<cmd>wincmd j<cr>", { desc = "Move down" })
map("n", "<leader>wk", "<cmd>wincmd k<cr>", { desc = "Move up" })
