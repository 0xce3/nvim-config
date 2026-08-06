-- WSL/Windows Terminal clipboard integration via OSC52. This avoids requiring
-- a clipboard executable inside WSL and works through remote-ui sessions too.
local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok then
  vim.g.clipboard = {
    name = "osc52",
    copy = {
      ["+"] = osc52.copy "+",
      ["*"] = osc52.copy "*",
    },
    paste = {
      ["+"] = function() return vim.fn.split(vim.fn.getreg "+", "\n") end,
      ["*"] = function() return vim.fn.split(vim.fn.getreg "*", "\n") end,
    },
  }
end

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(event)
    if vim.bo[event.buf].filetype == "snacks_terminal" then return end
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
      buffer = event.buf,
      silent = true,
      desc = "Leave terminal mode",
    })
  end,
  desc = "Leave normal terminal mode with Escape",
})

-- German layouts make Ctrl-\ awkward because the key requires AltGr. These
-- terminal-mode fallbacks enter Neovim normal mode without sending the key to
-- the running terminal program.
vim.keymap.set("t", "<C-Space>", [[<C-\><C-n>]], { silent = true, desc = "Leave terminal mode" })
vim.keymap.set("t", "<C-q>", [[<C-\><C-n>]], { silent = true, desc = "Leave terminal mode" })

vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")

-- Keep normal Vim yanks/deletes local. Use the explicit "+ register mappings
-- below for the system clipboard so OSC52 cannot shadow the unnamed register.
vim.opt.clipboard = ""
vim.keymap.set("n", "q", "<Nop>", { desc = "Disable macro recording" })

vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
vim.keymap.set("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("i", "<C-v>", '<C-r>+', { desc = "Paste from system clipboard" })
vim.keymap.set("v", "<C-x>", '"+d', { desc = "Cut selection to system clipboard" })

-- Set this after all AstroNvim plugin specs so no Git mapping can shadow it.
vim.keymap.set("n", "<leader>gl", function()
  require("config.lazygit").open()
end, { desc = "Open lazygit" })

vim.keymap.set({ "n", "v" }, "<leader>e", "<Cmd>Yazi toggle<CR>", { desc = "Open or resume yazi" })
vim.keymap.set("n", "<leader>E", "<Cmd>Yazi cwd<CR>", { desc = "Open yazi in working directory" })

vim.keymap.set("n", "<leader>gg", function()
  require("gitgraph").draw({}, { all = true, max_count = 5000 })
end, { desc = "Git graph" })

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  pattern = "*",
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "gitgraph" then return end
    vim.keymap.set("n", "<Esc>", function()
      local graph_buf = vim.api.nvim_get_current_buf()
      local alternate = vim.fn.bufnr("#")
      if alternate > 0 and alternate ~= graph_buf and vim.api.nvim_buf_is_valid(alternate) then
        vim.cmd("buffer " .. alternate)
      else
        vim.cmd("enew")
      end
      vim.api.nvim_buf_delete(graph_buf, { force = true })
    end, {
      buffer = args.buf,
      silent = true,
      nowait = true,
      desc = "Close GitGraph",
    })
  end,
})


-- VS Code tasks and the devcontainer workflow expect the user's login shell
-- environment, where tools such as west and project virtualenvs are exposed.
vim.opt.shell = "bash"
vim.opt.shellcmdflag = "-lc"

-- Keep clangd diagnostics aligned with the firmware toolchain. The wrapper
-- provides the matching container build directory when one is selected on the
-- host; the global config removes GCC-only flags that clangd cannot parse.
pcall(function() require("config.clangd_config").ensure() end)

vim.api.nvim_create_user_command("LspRestart", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    client:stop(true)
  end
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(0) then vim.cmd("edit") end
  end, 100)
end, { desc = "Restart LSP clients for the current buffer" })

vim.api.nvim_create_user_command("LspInfo", function()
  local lines = {}
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    lines[1] = "No active LSP clients for the current buffer."
  else
    for _, client in ipairs(clients) do
      lines[#lines + 1] = string.format("%s [%d]", client.name, client.id)
      lines[#lines + 1] = "  cmd: " .. (type(client.config.cmd) == "table" and table.concat(client.config.cmd, " ") or "dynamic")
      lines[#lines + 1] = "  root: " .. tostring(client.config.root_dir or "")
      lines[#lines + 1] = ""
    end
  end
  vim.cmd("botright new")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_name(0, "LspInfo")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end, { desc = "Show active LSP clients for the current buffer" })
