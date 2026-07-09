local map = vim.keymap.set

local function is_replacement_buffer(bufnr, current)
  if bufnr == current or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted then
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

  if require("config.terminal").is_terminal_buffer(current) then
    require("config.terminal").kill()
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

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(event)
    vim.keymap.set("n", "q", function()
      if require("config.terminal").is_terminal_buffer(event.buf) then
        require("config.terminal").kill()
      else
        vim.cmd("quit")
      end
    end, { buffer = event.buf, desc = "Close terminal buffer" })
    vim.cmd([[cnoreabbrev <buffer> <expr> q getcmdtype() == ':' && getcmdline() == 'q' ? 'BufferClose' : 'q']])
  end,
})

vim.api.nvim_create_user_command("Bd", function(opts)
  close_current_buffer(opts.bang)
end, { bang = true, desc = "Close current buffer without closing the editor layout" })

local c_like_filetypes = {
  c = true,
  cpp = true,
  h = true,
  hpp = true,
}

local function repo_root_for_file(filename)
  local dir = vim.fn.fnamemodify(filename, ":p:h")
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }):wait()
  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return nil
  end
  return vim.trim(result.stdout)
end

local function compliance_clang_format_file(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or vim.fn.filereadable(filename) ~= 1 then
    return
  end

  local root = repo_root_for_file(filename)
  if not root or vim.fn.filereadable(root .. "/.clang-format") ~= 1 then
    return
  end

  if vim.fn.executable("clang-format") ~= 1 then
    return
  end

  local rel = vim.fn.fnamemodify(filename, ":p"):sub(#root + 2)
  if rel:find("^modules/trusted%-firmware%-m/") or rel == "multisensor_firmware_generated.h" then
    return
  end

  local result = vim.system({ "clang-format", "--style=file", "-i", rel }, {
    cwd = root,
    text = true,
  }):wait()
  if result.code ~= 0 then
    vim.notify(result.stderr ~= "" and result.stderr or "clang-format failed", vim.log.levels.WARN)
    return
  end

  vim.cmd("checktime " .. bufnr)
end

local function format_buffer(bufnr)
  if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  if c_like_filetypes[filetype] then
    return
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
  local bufnr = vim.api.nvim_get_current_buf()
  if c_like_filetypes[vim.bo[bufnr].filetype] then
    compliance_clang_format_file(bufnr)
    return
  end
  format_buffer(bufnr)
end, { desc = "Format current buffer" })

vim.api.nvim_create_user_command("NvimDevDebug", function()
  local lines = {}
  local function add(label, value)
    table.insert(lines, label .. ": " .. tostring(value))
  end

  local file = vim.api.nvim_buf_get_name(0)
  local cc_dir = require("config.clangd_build").active(vim.fn.getcwd())
  add("cwd", vim.uv.cwd())
  add("file", file)
  add("filetype", vim.bo.filetype)
  add("DEVCONTAINER", vim.env.DEVCONTAINER)
  add("dockerenv", vim.fn.filereadable("/.dockerenv"))
  add("NVIM_CLANGD_COMPILE_COMMANDS_DIR", vim.env.NVIM_CLANGD_COMPILE_COMMANDS_DIR)
  add("clangd_build.active", cc_dir)
  add("compile_commands exists", cc_dir and vim.fn.filereadable(cc_dir .. "/compile_commands.json") or "nil")
  add("clangd executable", vim.fn.exepath("clangd"))
  add("C/C++ formatting", "clang-format --style=file using repo .clang-format")
  add("LspInfo command", vim.fn.exists(":LspInfo"))

  if vim.fn.executable("clangd") == 1 then
    local clangd_version = vim.system({ "clangd", "--version" }, { text = true }):wait()
    add("clangd version", vim.trim((clangd_version.stdout or clangd_version.stderr or ""):gsub("\n.*", "")))
  else
    add("clangd version", "not executable")
  end
  table.insert(lines, "")
  table.insert(lines, "LSP log:")
  table.insert(lines, vim.lsp.get_log_path())

  table.insert(lines, "")
  table.insert(lines, "LSP clients:")
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    table.insert(lines, vim.inspect({ name = client.name, cmd = client.config.cmd, root_dir = client.config.root_dir }))
  end

  local out = "/tmp/nvim-dev-debug.txt"
  vim.fn.writefile(lines, out)
  vim.cmd("edit " .. out)
end, { desc = "Write nvim devcontainer debug info" })

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(event)
    if vim.env.DEVCONTAINER == "true" then
      return
    end
    format_buffer(event.buf)
  end,
  desc = "Format buffer before saving",
})

vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function(event)
    if c_like_filetypes[vim.bo[event.buf].filetype] then
      compliance_clang_format_file(event.buf)
    end
  end,
  desc = "Format C/C++ buffers using repo .clang-format",
})

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- Move the current line / selection up and down with Alt+Up / Alt+Down
-- (VS Code style).
map("n", "<A-Down>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-Up>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("i", "<A-Down>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-Up>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Disable Ctrl+Z (suspend). This nvim runs inside `docker exec -it` under a
-- non-interactive shell, so a suspended nvim can't be brought back with `fg`
-- (job control is off) - the editor just gets stuck. Make Ctrl+Z a no-op.
map("n", "<C-z>", "<Nop>", { desc = "Disabled (no suspend)" })
map("i", "<C-z>", "<Nop>", { desc = "Disabled (no suspend)" })
map("v", "<C-z>", "<Nop>", { desc = "Disabled (no suspend)" })
-- Toggle between the two most recently edited files (the alternate buffer):
-- in file_a, open file_b, then <leader><Tab> flips back and forth.
map("n", "<leader><Tab>", "<cmd>buffer #<cr>", { desc = "Switch to last file" })
-- Open buffers through a picker instead of showing a persistent buffer tabline.
-- This takes over <C-i>; <C-o> still jumps back.
map("n", "<Tab>", function() require("fzf-lua").buffers() end, { desc = "Find buffers" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>x", "<cmd>BufferClose<cr>", { desc = "Close buffer" })
map("n", "<leader>X", "<cmd>BufferClose!<cr>", { desc = "Force close buffer" })

-- Windows-style copy: Ctrl+C in visual mode copies the selection to the system
-- clipboard (via OSC 52). Pasting from Windows is handled by the terminal's
-- Ctrl+V; selecting terminal/console text is handled by Windows Terminal.
map("v", "<C-c>", '"+y', { desc = "Copy selection to clipboard" })
map("v", "<C-x>", '"+d', { desc = "Cut selection to clipboard" })

local function open_file_browser(opts)
  require("telescope").extensions.file_browser.file_browser(vim.tbl_extend("force", {
    grouped = true,
    hidden = true,
    respect_gitignore = false,
    git_status = true,
    select_buffer = true,
  }, opts or {}))
end

map("n", "<leader>E", function()
  open_file_browser({
    path = vim.uv.cwd(),
    cwd = vim.uv.cwd(),
  })
end, { desc = "Open unrestricted file explorer" })
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
    map("n", "gi", "<C-o>", opts("Jump back"))
    map("n", "gI", vim.lsp.buf.implementation, opts("Go to implementation"))
    map("n", "gr", vim.lsp.buf.references, opts("Go to references"))
    map("n", "gh", vim.lsp.buf.hover, opts("Show hover documentation"))
    map("n", "<leader>lr", vim.lsp.buf.rename, opts("Rename symbol"))
    map("n", "<leader>la", vim.lsp.buf.code_action, opts("Code action"))
  end,
})

map("n", "<F12>", function() require("config.terminal").toggle() end, { desc = "Toggle terminal" })
map("t", "<F12>", function() require("config.terminal").toggle() end, { desc = "Toggle terminal" })

map("n", "<leader>hh", function() require("config.workspace_hub").open() end, { desc = "Open workspace hub" })
map("n", "<leader>rg", function() require("config.http_workspace").generate() end, { desc = "Generate HTTP workspace" })
map("n", "<leader>ro", function() require("config.http_workspace").open() end, { desc = "Open HTTP workspace" })
map("n", "<leader>rd", function() require("config.http_workspace").delete() end, { desc = "Delete HTTP workspace" })
map("n", "<leader>rp", function() require("config.http_workspace").pick_openapi() end, { desc = "Pick OpenAPI file" })

map("t", "<c-z>", [[<c-\><c-n>u]], { desc = "Undo in editor" })
map("t", "<esc><esc>", [[<c-\><c-n>]], { desc = "Leave terminal mode" })
map("t", "<c-h>", [[<cmd>wincmd h<cr>]], { desc = "Move left" })
map("t", "<c-j>", [[<cmd>wincmd j<cr>]], { desc = "Move down" })
map("t", "<c-k>", [[<cmd>wincmd k<cr>]], { desc = "Move up" })
map("t", "<c-l>", [[<cmd>wincmd l<cr>]], { desc = "Move right" })
map({ "n", "t" }, "<leader>tp", function() require("config.terminal").tmux("p") end, { desc = "tmux previous window" })
map({ "n", "t" }, "<leader>tn", function() require("config.terminal").tmux("n") end, { desc = "tmux next window" })
for i = 1, 9 do
  map({ "n", "t" }, "<leader>t" .. i, function() require("config.terminal").tmux(tostring(i)) end, { desc = "tmux window " .. i })
end

map("n", "<c-h>", "<cmd>wincmd h<cr>", { desc = "Move left" })
map("n", "<c-j>", "<cmd>wincmd j<cr>", { desc = "Move down" })
map("n", "<c-k>", "<cmd>wincmd k<cr>", { desc = "Move up" })
map("n", "<c-l>", "<cmd>wincmd l<cr>", { desc = "Move right" })
map("n", "<leader>wh", "<cmd>wincmd h<cr>", { desc = "Move left" })
map("n", "<leader>wl", "<cmd>wincmd l<cr>", { desc = "Move right" })
map("n", "<leader>wj", "<cmd>wincmd j<cr>", { desc = "Move down" })
map("n", "<leader>wk", "<cmd>wincmd k<cr>", { desc = "Move up" })
