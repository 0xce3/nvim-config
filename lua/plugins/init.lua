return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "soft",
        transparent_mode = false,
        terminal_colors = true,
      })

      vim.o.background = "dark"
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 34,
          side = "left",
        },
        renderer = {
          group_empty = true,
          highlight_git = true,
          indent_markers = {
            enable = true,
          },
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        git = {
          enable = true,
          ignore = false,
        },
        filters = {
          dotfiles = false,
          git_ignored = false,
        },
        actions = {
          open_file = {
            quit_on_open = false,
          },
        },
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          require("nvim-tree.api").tree.open()
        end,
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "gruvbox",
          globalstatus = true,
          component_separators = "|",
          section_separators = "",
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "thin",
          show_close_icon = false,
          show_buffer_close_icons = true,
          always_show_bufferline = true,
          offsets = {
            {
              filetype = "NvimTree",
              text = "Explorer",
              text_align = "left",
              separator = true,
            },
          },
        },
      })
    end,
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        direction = "horizontal",
        size = 15,
        open_mapping = [[<F12>]],
      })
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  {
    "tpope/vim-fugitive",
  },

  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("octo").setup()

      local map = vim.keymap.set
      map("n", "<leader>pr",  "<cmd>Octo pr list<cr>",     { desc = "List PRs" })
      map("n", "<leader>prc", "<cmd>Octo pr create<cr>",   { desc = "Create PR" })
      map("n", "<leader>prr", "<cmd>Octo review start<cr>", { desc = "Start PR review" })
      map("n", "<leader>pi",  "<cmd>Octo issue list<cr>",  { desc = "List issues" })
    end,
  },

  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { preview_width = 0.55 },
        },
      })
      telescope.load_extension("fzf")

      local builtin = require("telescope.builtin")
      local map = vim.keymap.set
      map("n", "<C-p>",      builtin.find_files,  { desc = "Find files" })
      map("n", "<leader>ff", builtin.find_files,  { desc = "Find files" })
      map("n", "<leader>fg", builtin.live_grep,   { desc = "Live grep" })
      map("n", "<leader>fb", builtin.buffers,     { desc = "Find buffers" })
      map("n", "<leader>fh", builtin.help_tags,   { desc = "Help tags" })
      map("n", "<leader>fr", builtin.oldfiles,    { desc = "Recent files" })
      map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
    end,
  },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
        end,
      },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-d>"]     = cmp.mapping.scroll_docs(4),
          ["<C-u>"]     = cmp.mapping.scroll_docs(-4),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer", keyword_length = 3 },
        }),
        formatting = {
          format = function(entry, item)
            local source_labels = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              buffer   = "[Buf]",
              path     = "[Path]",
            }
            item.menu = source_labels[entry.source.name] or ""
            return item
          end,
        },
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c",
          "cpp",
          "python",
          "lua",
          "cmake",
          "json",
          "yaml",
          "bash",
          "markdown",
        },
        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      local function find_compile_commands_dir()
        local candidates = {
          "build",
          "build/debug",
          "build_native_clang_debug",
          "main_app/build",
          "main_app/build_native_clang_debug",
        }

        for _, dir in ipairs(candidates) do
          local path = vim.fn.getcwd() .. "/" .. dir .. "/compile_commands.json"
          if vim.fn.filereadable(path) == 1 then
            return vim.fn.getcwd() .. "/" .. dir
          end
        end

        return nil
      end

      local clangd_cmd = { "clangd" }
      local compile_commands_dir = find_compile_commands_dir()
      if compile_commands_dir then
        table.insert(clangd_cmd, "--compile-commands-dir=" .. compile_commands_dir)
      end

      vim.lsp.config("clangd", {
        cmd = clangd_cmd,
      })

      vim.lsp.config("pyright", {
        cmd = { "pyright-langserver", "--stdio" },
      })

      vim.lsp.config("ruff", {
        cmd = { "ruff", "server" },
      })

      vim.lsp.enable({
        "clangd",
        "pyright",
        "ruff",
      })
    end,
  },
}
