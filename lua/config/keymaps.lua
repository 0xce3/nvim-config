local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })
map("n", "<leader>gg", "<cmd>Git<cr>", { desc = "Open Git status" })
map("n", "K", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>dp", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "<leader>dn", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostics list" })

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
