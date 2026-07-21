return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.win = opts.picker.win or {}
      opts.picker.win.input = opts.picker.win.input or {}
      opts.picker.win.input.keys = opts.picker.win.input.keys or {}
      opts.picker.win.input.keys["<S-j>"] = { "preview_scroll_down", mode = { "n", "i" } }
      opts.picker.win.input.keys["<S-k>"] = { "preview_scroll_up", mode = { "n", "i" } }
      opts.picker.win.input.keys["<S-Down>"] = { "preview_scroll_down", mode = { "n", "i" } }
      opts.picker.win.input.keys["<S-Up>"] = { "preview_scroll_up", mode = { "n", "i" } }
      opts.picker.win.list = opts.picker.win.list or {}
      opts.picker.win.list.keys = opts.picker.win.list.keys or {}
      opts.picker.win.list.keys["<S-j>"] = "preview_scroll_down"
      opts.picker.win.list.keys["<S-k>"] = "preview_scroll_up"
      opts.picker.win.list.keys["<S-Down>"] = "preview_scroll_down"
      opts.picker.win.list.keys["<S-Up>"] = "preview_scroll_up"
    end,
  },
}
