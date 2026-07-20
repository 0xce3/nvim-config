-- Automatically insert the closing pair when typing an opening bracket/quote
-- ({} [] () "" '' ``). Context-aware: it won't add a duplicate when a closing
-- character already follows, and <BS> deletes both halves of an empty pair.
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      local autopairs = require("nvim-autopairs")
      autopairs.setup({
        check_ts = true, -- use Treesitter to avoid pairing inside strings/comments
        fast_wrap = {}, -- <M-e> to wrap the next token in a pair
      })

      -- When confirming a completion that is a function, also insert "()".
      local ok, cmp = pcall(require, "cmp")
      if ok then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },
}
