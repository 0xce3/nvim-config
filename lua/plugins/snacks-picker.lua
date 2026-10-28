return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- Tree-style browsing of the cwd. The files picker stays fuzzy/recursive.
      opts.explorer = opts.explorer or {}
      opts.explorer.enabled = true
      opts.explorer.replace_netrw = true
      opts.explorer.trash = true
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.explorer = opts.picker.sources.explorer or {}
      -- Close the sidebar as soon as focus moves to another window.
      opts.picker.sources.explorer.auto_close = true
      -- Browsing should show everything: dotfiles and gitignored trees too.
      opts.picker.sources.explorer.hidden = true
      opts.picker.sources.explorer.ignored = true
      opts.picker.sources.files = opts.picker.sources.files or {}
      -- Keep the frequent file picker fast. Hidden/generated trees such as
      -- .west_workspace and build caches are available through <C-P>.
      opts.picker.sources.files.hidden = false
      opts.picker.sources.grep = opts.picker.sources.grep or {}
      opts.picker.sources.grep.hidden = true
      opts.picker.win = opts.picker.win or {}
      opts.picker.win.input = opts.picker.win.input or {}
      opts.picker.win.input.keys = opts.picker.win.input.keys or {}
      opts.picker.win.input.keys["<Esc>"] = { "close", mode = { "n", "i" } }
      opts.picker.win.input.keys["<S-j>"] = { "preview_scroll_down", mode = { "n", "i" } }
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
