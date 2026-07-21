-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
local function close_buffer(bufnr, force)
  if vim.bo[bufnr].filetype == "csv" then
    local ok, csvview = pcall(require, "csvview")
    if ok then pcall(csvview.disable, bufnr) end
  end
  require("astrocore.buffer").close(bufnr, force)
end

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
        yaml = "yaml",
        yml = "yaml",
        http = "http",
        rest = "http",
        bb = "bitbake",
        bbappend = "bitbake",
        bbclass = "bitbake",
      },
      pattern = {
        [".*/conf/.*%.conf"] = "bitbake",
        [".*/recipes%-.*/.*%.inc"] = "bitbake",
        [".*/classes/.*%.inc"] = "bitbake",
      },
    },
    autocmds = {
      csv_delimiter = {
        {
          event = "FileType",
          pattern = "csv",
          callback = function(args)
            local line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ""
            local semicolons = select(2, line:gsub(";", ""))
            local commas = select(2, line:gsub(",", ""))
            local delimiter = semicolons > commas and ";" or ","

            vim.b[args.buf].csv_delimiter = delimiter
            vim.bo[args.buf].syntax = ""
            vim.cmd("syntax off")
            vim.cmd("unlet! b:current_syntax")
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(args.buf) then return end
              pcall(vim.treesitter.stop, args.buf)
              vim.api.nvim_buf_call(args.buf, function() vim.cmd("syntax on") end)
            end)
          end,
          desc = "Detect CSV delimiter before applying syntax highlighting",
        },
      },
    },
    treesitter = {
      ensure_installed = { "yaml" },
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        clipboard = "", -- keep normal yanks/deletes local; use "+" explicitly for OSC52
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
        ["<leader>c"] = {
          function() close_buffer(0, false) end,
          desc = "Close buffer",
        },
        ["<leader>C"] = {
          function() close_buffer(0, true) end,
          desc = "Force close buffer",
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
              function(bufnr) close_buffer(bufnr, false) end
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
