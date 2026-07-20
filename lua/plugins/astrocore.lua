-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- passed to `vim.filetype.add`
    filetypes = {
      -- see `:h vim.filetype.add` for usage
      extension = {
          conf = "kconf",
          http = "http",
          rest = "http",
          bb = "bitbake",
          bbappend = "bitbake",
          bbclass = "bitbake",
      },
      filename = {
          [".*/conf/.*%.conf"] = "bitbake",
      },
      pattern = {
          [".*/recipes%-.*/.*%.inc"] = "bitbake",
          [".*/classes/.*%.inc"] = "bitbake",
      },
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes", -- sets vim.opt.signcolumn to yes
          wrap = false, -- sets vim.opt.wrap
          mouse = "a",
          termguicolors = true,
          cursorline = true,
          splitright = true,
          splitbelow = true,
          ignorecase = true,
          smartcase = true,
          expandtab = true,
          shiftwidth = 2,
          tabstop = 2,
          smartindent = true,
          foldmethod = "indent",
          foldlevel = 99,
          foldlevelstart = 99,
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      n = {
        ["<S-w>"] = { "<C-w>w", desc = "Switch window" },
        ["<F12>"] = {
          function() require("config.terminal").toggle() end,
          desc = "Toggle task terminal",
        },
        ["<leader>td"] = {
          function() require("config.terminal").toggle_debug() end,
          desc = "Toggle debug terminal",
        },
        ["go"] = { "<C-o>", desc = "Jump back" },
        ["<Leader>gl"] = {
          function()
            local ok, snacks = pcall(require, "snacks")
            if not ok then
              vim.notify("snacks.nvim is not available", vim.log.levels.ERROR)
              return
            end
            snacks.lazygit.open()
          end,
          desc = "Open lazygit",
        },
        ["<Leader>fg"] = {
          function()
            local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
            require("snacks").picker.grep({ cwd = root })
          end,
          desc = "Grep project",
        },
        ["<Leader>fw"] = {
          function() require("snacks").picker.grep_word() end,
          desc = "Grep word under cursor",
        },
        -- second key is the lefthand side of the map
        ["<C-p>"] = {
          function() require("snacks").picker.files() end,
          desc = "Find files",
        },
        ["<Tab>"] = {
          function() require("astrocore.buffer").nav(vim.v.count1) end,
          desc = "Next buffer",
        },
        ["<S-Tab>"] = {
          function() require("astrocore.buffer").nav(-vim.v.count1) end,
          desc = "Previous buffer",
        },
        ["<Leader><Tab>"] = { "<Cmd>buffer #<CR>", desc = "Switch to last buffer" },

        -- navigate buffer tabs
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,
      },
      t = {
        ["<F12>"] = {
          function() require("config.terminal").toggle() end,
          desc = "Toggle task terminal",
        },
      },
    },
  },
}
