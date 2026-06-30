return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "soft",
        transparent_mode = false,
        terminal_colors = true,
        overrides = {
          PmenuSbar  = { bg = "#504945" },
          PmenuThumb = { bg = "#928374" },
        },
      })

      vim.o.background = "dark"
      vim.cmd.colorscheme("gruvbox")

      -- Gruvbox Soft Dark syntax palette tuned for readability: each role gets
      -- a distinct Gruvbox hue, and variables stay cream (the Gruvbox "white")
      -- so the bulk of the code reads neutral and only keywords/functions/types/
      -- constants/strings pop. The @lsp.type.* groups are set too, otherwise
      -- clangd's semantic tokens override the Treesitter colours.
      local function apply_gruvbox_fixes()
        local c = {
          keyword = "#fb4934", -- red
          func    = "#fabd2f", -- yellow
          type    = "#8ec07c", -- aqua
          var     = "#ebdbb2", -- cream (default fg)
          const   = "#d3869b", -- purple
          number  = "#d3869b", -- purple
          string  = "#b8bb26", -- green
          comment = "#928374", -- gray
          preproc = "#fe8019", -- orange
          op      = "#fe8019", -- orange (operators / ; , so they stand out)
          member  = "#83a598", -- blue (struct/object members: foo.member)
          fg      = "#ebdbb2", -- cream
        }
        local function hl(group, opts)
          vim.api.nvim_set_hl(0, group, opts)
        end

        -- Default text -> cream. Operators (++ > < ! == = * &) and statement
        -- delimiters (; ,) -> orange so they stand out from identifiers.
        -- Brackets are left to rainbow-delimiters (depth colours).
        hl("Normal", { fg = c.fg })
        hl("Operator", { fg = c.op })
        hl("Delimiter", { fg = c.op })
        hl("@operator", { fg = c.op })
        hl("@punctuation.delimiter", { fg = c.op })
        hl("@punctuation.special", { fg = c.op })
        hl("@lsp.type.operator", { fg = c.op })

        -- Comments
        hl("Comment", { fg = c.comment, italic = false })
        hl("@comment", { fg = c.comment, italic = false })
        hl("@lsp.type.comment", {})

        -- Strings / chars
        hl("String", { fg = c.string })
        hl("Character", { fg = c.string })
        hl("@string", { fg = c.string })
        hl("@string.special.path", { fg = c.string, underline = false })
        hl("@character", { fg = c.string })
        hl("cIncluded", { fg = c.string })
        -- Escape sequences (\n, \0, \t) -> orange so they stand out from text
        hl("SpecialChar", { fg = c.op })
        hl("@string.escape", { fg = c.op, bold = true })
        hl("@string.special.symbol", { fg = c.op })

        -- Numbers / booleans
        hl("Number", { fg = c.number })
        hl("Float", { fg = c.number })
        hl("@number", { fg = c.number })
        hl("@number.float", { fg = c.number })
        hl("Boolean", { fg = c.const })
        hl("@boolean", { fg = c.const })

        -- Keywords / storage / control flow -> blue
        hl("Keyword", { fg = c.keyword })
        hl("Statement", { fg = c.keyword })
        hl("Conditional", { fg = c.keyword })
        hl("Repeat", { fg = c.keyword })
        hl("Label", { fg = c.keyword })
        hl("Exception", { fg = c.keyword })
        hl("StorageClass", { fg = c.keyword })
        hl("Structure", { fg = c.keyword })
        hl("@keyword", { fg = c.keyword })
        hl("@keyword.function", { fg = c.keyword })
        hl("@keyword.return", { fg = c.keyword })
        hl("@keyword.operator", { fg = c.keyword })
        hl("@keyword.conditional", { fg = c.keyword })
        hl("@keyword.repeat", { fg = c.keyword })
        hl("@conditional", { fg = c.keyword })
        hl("@repeat", { fg = c.keyword })
        hl("@lsp.type.keyword", { fg = c.keyword })
        hl("@lsp.type.modifier", { fg = c.keyword })

        -- Functions (definitions and calls) -> pale yellow, no bold
        hl("Function", { fg = c.func, bold = false })
        hl("@function", { fg = c.func, bold = false })
        hl("@function.call", { fg = c.func, bold = false })
        hl("@function.method", { fg = c.func, bold = false })
        hl("@function.method.call", { fg = c.func, bold = false })
        hl("@function.builtin", { fg = c.func, bold = false })
        hl("@function.macro", { fg = c.func, bold = false })
        hl("@constructor", { fg = c.func, bold = false })
        hl("@lsp.type.function", { fg = c.func, bold = false })
        hl("@lsp.type.method", { fg = c.func, bold = false })

        -- User-defined types / structs -> teal. Type keywords (struct/enum/union)
        -- and builtin/stdlib types (int, void, uint8_t, size_t) -> orange.
        hl("Type", { fg = c.type })
        hl("Typedef", { fg = c.type })
        hl("@type", { fg = c.type })
        hl("@type.definition", { fg = c.type })
        hl("@type.builtin", { fg = c.op })
        hl("@type.qualifier", { fg = c.op })
        hl("@keyword.type", { fg = c.op })
        hl("@lsp.type.type", { fg = c.type })
        hl("@lsp.type.class", { fg = c.type })
        hl("@lsp.type.struct", { fg = c.type })
        hl("@lsp.type.enum", { fg = c.type })
        hl("@lsp.type.typeParameter", { fg = c.type })
        hl("@lsp.typemod.type.defaultLibrary", { fg = c.op })

        -- Variables / parameters / struct members -> light blue
        hl("Identifier", { fg = c.var })
        hl("@variable", { fg = c.var })
        hl("@variable.parameter", { fg = c.var })
        hl("@variable.member", { fg = c.member })
        hl("@variable.builtin", { fg = c.keyword })
        hl("@property", { fg = c.member })
        hl("@field", { fg = c.member })
        hl("@parameter", { fg = c.var })
        hl("@lsp.type.variable", { fg = c.var })
        hl("@lsp.type.parameter", { fg = c.var })
        hl("@lsp.type.property", { fg = c.member })
        hl("@lsp.type.namespace", { fg = c.var })

        -- Constants / enum members / macro *uses* -> purple. Macro *definition*
        -- names (#define NAME ...) -> yellow.
        hl("Constant", { fg = c.const })
        hl("Macro", { fg = c.func })
        hl("@constant", { fg = c.const })
        hl("@constant.builtin", { fg = c.const })
        hl("@constant.macro", { fg = c.func })
        hl("@module", { fg = c.var })
        hl("@lsp.type.macro", { fg = c.const })
        hl("@lsp.typemod.macro.declaration", { fg = c.func })
        hl("@lsp.typemod.macro.definition", { fg = c.func })
        hl("@lsp.type.enumMember", { fg = c.const })

        -- Preprocessor: #if / #define / #endif directives -> orange. The
        -- #include directive -> green (matches the string-coloured path that
        -- follows). The leading '#' of every directive is greyed separately by
        -- config.preproc (it shares one Treesitter token with the keyword).
        hl("PreProc", { fg = c.preproc })
        hl("PreCondit", { fg = c.preproc })
        hl("Define", { fg = c.preproc })
        hl("@keyword.directive", { fg = c.preproc })
        hl("@keyword.directive.define", { fg = c.preproc })
        hl("@preproc", { fg = c.preproc })
        hl("Include", { fg = c.string })
        hl("@keyword.import", { fg = c.string })

        -- UI highlights kept from the previous gruvbox tuning
        hl("Search", { fg = "#ebdbb2", bg = "#504945", reverse = false })
        hl("IncSearch", { fg = "#282828", bg = "#fabd2f", reverse = false })
        hl("CurSearch", { fg = "#282828", bg = "#fabd2f", reverse = false })
        hl("Visual", { bg = "#504945", reverse = false })

        -- Closed folds: readable cream text on a subtle background (NOT greyed
        -- out, so a folded function doesn't look disabled). Fold gutter chevrons
        -- in a muted grey.
        hl("Folded", { fg = "#ebdbb2", bg = "#3c3836", italic = false })
        hl("FoldColumn", { fg = "#928374", bg = "NONE" })
      end

      apply_gruvbox_fixes()

      -- Re-apply scrollbar highlights after gruvbox to prevent override
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          apply_gruvbox_fixes()
          vim.api.nvim_set_hl(0, "ScrollbarHandle",        { bg = "#504945", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarError",         { fg = "#fb4934", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarErrorHandle",   { fg = "#fb4934", bg = "#504945", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarWarn",          { fg = "#fabd2f", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarWarnHandle",    { fg = "#fabd2f", bg = "#504945", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarGitAdd",        { fg = "#b8bb26", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarGitAddHandle",  { fg = "#b8bb26", bg = "#504945", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarGitChange",     { fg = "#fabd2f", default = false })
          vim.api.nvim_set_hl(0, "ScrollbarGitChangeHandle", { fg = "#fabd2f", bg = "#504945", default = false })
        end,
      })
    end,
  },

  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    config = function()
      require("nvim-web-devicons").setup({
        color_icons = false,
        default = true,
      })
    end,
  },

  {
    "petertriho/nvim-scrollbar",
    config = function()
      require("scrollbar").setup({
        handlers = {
          cursor     = false,
          diagnostic = true,
          gitsigns   = false,
          search     = false,
        },
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function clangd_build()
        local name = require("config.clangd_build").active_name(vim.fn.getcwd())
        if not name then
          return ""
        end
        return "clangd:" .. name
      end

      local function container_status()
        return require("config.devcontainer").statusline()
      end

      local function container_status_color()
        return require("config.devcontainer").statusline_color()
      end

      require("lualine").setup({
        options = {
          theme = "gruvbox",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },

        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { { container_status, color = container_status_color }, "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { clangd_build, "encoding", "fileformat", "filetype" },
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
      local colors = require("gruvbox").palette
      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "thin",
          indicator = { style = "icon", icon = "▎" },
          -- Show the full filename; only shorten when the bar actually runs out
          -- of room (not at a fixed 18-char cutoff).
          max_name_length = 40,
          tab_size = 16,
          truncate_names = false,
          show_close_icon = false,
          show_buffer_close_icons = true,
          always_show_bufferline = true,
          offsets = {},
        },
        highlights = {
          fill = {
            bg = colors.dark0_soft,
          },
          -- Inactive buffers: muted grey + italic so they clearly recede.
          background = {
            fg = colors.gray,
            bg = colors.dark0_soft,
            italic = true,
          },
          buffer_visible = {
            fg = colors.light4,
            bg = colors.dark0_soft,
            italic = true,
          },
          -- Active buffer: bright, bold, with an orange accent bar on the left.
          buffer_selected = {
            fg = colors.light1,
            bg = colors.dark1,
            bold = true,
            italic = false,
          },
          indicator_selected = {
            fg = colors.bright_orange,
            bg = colors.dark1,
          },
          numbers_selected = {
            fg = colors.light1,
            bg = colors.dark1,
            bold = true,
          },
          -- Close 'X' icons -> gruvbox red.
          close_button = {
            fg = colors.bright_red,
            bg = colors.dark0_soft,
          },
          close_button_visible = {
            fg = colors.bright_red,
            bg = colors.dark0_soft,
          },
          close_button_selected = {
            fg = colors.bright_red,
            bg = colors.dark1,
          },
          -- Modified dot -> orange in every state.
          modified = {
            fg = colors.bright_orange,
            bg = colors.dark0_soft,
          },
          modified_visible = {
            fg = colors.bright_orange,
            bg = colors.dark0_soft,
          },
          modified_selected = {
            fg = colors.bright_orange,
            bg = colors.dark1,
          },
          tab = {
            bg = colors.dark0_soft,
          },
          tab_selected = {
            bg = colors.dark1,
            bold = true,
          },
          tab_separator = {
            bg = colors.dark0_soft,
            fg = colors.dark2,
          },
          tab_separator_selected = {
            bg = colors.dark1,
            fg = colors.dark2,
          },
          separator = {
            bg = colors.dark0_soft,
            fg = colors.dark2,
          },
          separator_visible = {
            bg = colors.dark0_soft,
            fg = colors.dark2,
          },
          separator_selected = {
            bg = colors.dark1,
            fg = colors.dark2,
          },
          offset_separator = {
            bg = colors.dark0_soft,
            fg = colors.dark2,
          },
        },
      })
    end,
  },

  {
    "EthanJWright/vs-tasks.nvim",
    dependencies = {
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      local function find_task_root()
        local cwd = vim.uv.cwd()
        local project_name = vim.fn.fnamemodify(cwd, ":t")

        local function valid_root(path)
          return path and path ~= "" and vim.fn.isdirectory(path) == 1 and vim.fn.filereadable(vim.fs.joinpath(path, ".vscode", "tasks.json")) == 1
        end

        if valid_root(vim.env.NVIM_TASK_WORKSPACE_FOLDER) then
          return vim.env.NVIM_TASK_WORKSPACE_FOLDER
        end

        local home = vim.env.HOME or ""
        for _, base in ipairs({ "workspace", "workspaces", "west" .. "_" .. "workspace" }) do
          local candidate = vim.fs.joinpath(home, base, project_name)
          if valid_root(candidate) then
            return candidate
          end
        end

        for name, type_ in vim.fs.dir(cwd) do
          if type_ == "directory" and name:match("^%.") and name:lower():find("workspace", 1, true) then
            local mirrored = vim.fs.joinpath(cwd, name, project_name)
            if valid_root(mirrored) then
              return mirrored
            end
          end
        end

        local matches = vim.fs.find({ ".vscode", ".git" }, { upward = true, path = cwd })
        if #matches == 0 then
          return cwd
        end
        return vim.fs.dirname(matches[1])
      end

      local function decode_jsonc(text)
        local out = {}
        local i = 1
        local len = #text
        local in_string = false
        local quote = nil
        local escaped = false

        while i <= len do
          local ch = text:sub(i, i)
          local next_ch = text:sub(i + 1, i + 1)

          if in_string then
            table.insert(out, ch)
            if escaped then
              escaped = false
            elseif ch == "\\" then
              escaped = true
            elseif ch == quote then
              in_string = false
              quote = nil
            end
            i = i + 1
          elseif ch == '"' or ch == "'" then
            in_string = true
            quote = ch
            table.insert(out, ch)
            i = i + 1
          elseif ch == "/" and next_ch == "/" then
            i = i + 2
            while i <= len and text:sub(i, i) ~= "\n" do
              i = i + 1
            end
          elseif ch == "/" and next_ch == "*" then
            i = i + 2
            while i <= len and not (text:sub(i, i) == "*" and text:sub(i + 1, i + 1) == "/") do
              i = i + 1
            end
            i = i + 2
          else
            table.insert(out, ch)
            i = i + 1
          end
        end

        local without_comments = table.concat(out)
        local without_trailing_commas = without_comments:gsub(",%s*([}%]])", "%1")
        return vim.json.decode(without_trailing_commas)
      end

      local task_root = find_task_root()
      if vim.env.PROJECT_ROOT == nil or vim.env.PROJECT_ROOT == "" then
        vim.env.PROJECT_ROOT = task_root
      end
      if vim.env.WORKSPACE_FOLDER == nil or vim.env.WORKSPACE_FOLDER == "" then
        vim.env.WORKSPACE_FOLDER = task_root
      end
      local vstask_job = require("vstask.Job")
      local vstask_parse = require("vstask.Parse")
      local function expand_vscode_vars(value)
        if type(value) ~= "string" then
          return value
        end
        value = value:gsub("%${workspaceFolder}", task_root)
        value = value:gsub("%${env:([^}]+)}", function(name)
          return vim.env[name] or ""
        end)
        return value
      end

      local build_launch = vstask_parse.Build_launch
      vstask_parse.Build_launch = function(command, args)
        local expanded_args = {}
        for _, arg in ipairs(args or {}) do
          table.insert(expanded_args, expand_vscode_vars(arg))
        end
        return build_launch(command, expanded_args)
      end

      vstask_job.clean_command = function(command, options)
        local cleaned = expand_vscode_vars(command)
        if type(options) == "table" and type(options.env) == "table" then
          local exports = {}
          for key, value in pairs(options.env) do
            table.insert(exports, "export " .. key .. "=" .. vim.fn.shellescape(expand_vscode_vars(value)))
          end
          if #exports > 0 then
            cleaned = table.concat(exports, "; ") .. "; " .. cleaned
          end
        end
        local activate = nil
        if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
          activate = ". " .. vim.fn.shellescape(vim.env.VIRTUAL_ENV .. "/bin/activate") .. " 2>/dev/null"
        end
        local prefix = activate and (activate .. " && ") or ""

        if type(options) == "table" and type(options.cwd) == "string" then
          local cwd = expand_vscode_vars(options.cwd)
          return prefix .. "cd " .. vim.fn.shellescape(cwd) .. " && { " .. cleaned .. "; }"
        end
        return prefix .. "cd " .. vim.fn.shellescape(task_root) .. " && { " .. cleaned .. "; }"
      end

      -- Tasks run in the single reusable terminal buffer (see lua/config/terminal.lua).
      local term = require("config.terminal")

      vstask_job.start_job = function(opts)
        if opts == nil or opts.terminal == false then
          return
        end
        term.run(opts.command)
      end

      local function find_task_by_label(tasks, label)
        for _, task in ipairs(tasks) do
          if task.label == label then
            return task
          end
        end
        return nil
      end

      vstask_job.run_dependent_tasks = function(task, task_list)
        local commands = {}
        local deps = type(task.dependsOn) == "string" and { task.dependsOn } or task.dependsOn or {}

        for _, dep_label in ipairs(deps) do
          local dep_task = find_task_by_label(task_list, dep_label)
          if dep_task == nil then
            vim.notify("Dependent task not found: " .. dep_label, vim.log.levels.ERROR)
            return
          end
          table.insert(commands, vstask_job.clean_command(dep_task.command, dep_task.options))
        end

        if task.command ~= nil then
          table.insert(commands, vstask_job.clean_command(task.command, task.options))
        end

        vstask_job.start_job({
          label = task.label,
          command = table.concat(commands, " && "),
          silent = false,
          watch = false,
          terminal = true,
          direction = "horizontal",
        })
      end

      require("vstask").setup({
        cache_json_conf = false,
        cache_strategy = "last",
        config_dir = ".vscode",
        support_code_workspace = true,
        json_parser = decode_jsonc,
        telescope_keys = {
          vertical = "<C-v>",
          split = "<CR>",
          tab = "<C-t>",
          current = "<C-e>",
          background = "<C-b>",
          watch_job = "<C-w>",
          kill_job = "<C-d>",
          run = "<C-r>",
        },
      })

      local map = vim.keymap.set
      map("n", "<leader>tr", function()
        require("vstask").tasks()
      end, { desc = "Run VS Code task" })
      map("n", "<leader>tt", function()
        require("vstask").jobs()
      end, { desc = "Show task jobs" })
      map("n", "<leader>ti", function()
        require("vstask").inputs()
      end, { desc = "Set task inputs" })
      map("n", "<leader>tl", function()
        require("vstask").launches()
      end, { desc = "Run launch config" })
      map("n", "<leader>ts", function()
        require("vstask").command()
      end, { desc = "Run shell task" })
      map("n", "<leader>tj", term.toggle, { desc = "Toggle task terminal" })
        map("n", "<leader>tq", term.close, { desc = "Leave task terminal" })
    end,
  },

  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          "cpptools",
        },
        auto_update = false,
        run_on_start = true,
      })
    end,
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "EthanJWright/vs-tasks.nvim",
      "williamboman/mason.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
      require("nvim-dap-virtual-text").setup()
      require("config.vscode_debug").setup()
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree filesystem reveal left<cr>", desc = "Open file explorer" },
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = false,
        enable_git_status = true,
        enable_diagnostics = true,
        filesystem = {
          bind_to_cwd = false,
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
        },
        default_component_configs = {
          git_status = {
            symbols = {
              added = "A",
              modified = "M",
              deleted = "D",
              renamed = "R",
              untracked = "?",
              ignored = "I",
              unstaged = "U",
              staged = "S",
              conflict = "C",
            },
          },
          diagnostics = {
            symbols = {
              hint = "H",
              info = "I",
              warn = "W",
              error = "E",
            },
          },
        },
        window = {
          width = 36,
          mappings = {
            ["a"] = "add",
            ["d"] = "delete",
            ["r"] = "rename",
            ["m"] = "move",
          },
        },
      })

      vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = "#83a598" })
      vim.api.nvim_set_hl(0, "NeoTreeGitAdded", { fg = "#b8bb26" })
      vim.api.nvim_set_hl(0, "NeoTreeGitModified", { fg = "#fabd2f" })
      vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#b8bb26" })
      vim.api.nvim_set_hl(0, "NeoTreeGitDeleted", { fg = "#fb4934" })
      vim.api.nvim_set_hl(0, "NeoTreeGitConflict", { fg = "#fb4934", bold = true })
      vim.api.nvim_set_hl(0, "NeoTreeDiagnosticError", { fg = "#fb4934" })
      vim.api.nvim_set_hl(0, "NeoTreeDiagnosticWarn", { fg = "#fabd2f" })
      vim.api.nvim_set_hl(0, "NeoTreeDiagnosticInfo", { fg = "#83a598" })
      vim.api.nvim_set_hl(0, "NeoTreeDiagnosticHint", { fg = "#8ec07c" })
    end,
  },

  {
    "tpope/vim-fugitive",
  },

  -- UI toolkit used by opencode.nvim (managed terminal), lazygit, and
  -- the Workspace Hub dashboard. Every other module is explicitly disabled.
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      terminal = { enabled = true },
      lazygit = { enabled = true },
      bigfile = { enabled = false },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "h", desc = "Workspace Hub", action = ":lua require('config.workspace_hub').open()" },
            { icon = " ", key = "a", desc = "Attach Container", action = ":DevcontainerAttach" },
            { icon = " ", key = "o", desc = "Reopen in Devcontainer", action = ":DevcontainerReopen" },
            { icon = " ", key = "b", desc = "Rebuild Devcontainer", action = ":DevcontainerRebuild" },
            { icon = " ", key = "s", desc = "Restore Session", action = '<cmd>lua require("persistence").load()<CR>' },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
      explorer = { enabled = false },
      image = { enabled = false },
      indent = { enabled = false },
      input = { enabled = false },
      notifier = { enabled = false },
      picker = { enabled = false },
      quickfile = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    },
    keys = {
      {
        "<leader>gl",
        function()
          require("snacks").lazygit.open()
        end,
        desc = "Open lazygit",
      },
      {
        "<leader>gL",
        function()
          require("snacks").lazygit.log()
        end,
        desc = "Lazygit log (cwd)",
      },
    },
  },

  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      {
        "<leader>oa",
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        mode = { "n", "x" },
        desc = "Ask opencode",
      },
      {
        "<leader>oo",
        function()
          require("opencode").select()
        end,
        mode = { "n", "x" },
        desc = "Select opencode action",
      },
      {
        "<leader>ot",
        function()
          require("snacks.terminal").toggle("opencode --port", {
            win = { position = "right", width = 0.40, enter = false },
          })
        end,
        desc = "Toggle opencode window",
      },
      {
        "<leader>on",
        function()
          require("opencode").command("session.new")
        end,
        desc = "New opencode session",
      },
      {
        "<leader>os",
        function()
          require("opencode").command("session.select")
        end,
        desc = "Select opencode session",
      },
      {
        "<leader>ou",
        function()
          require("opencode").command("session.undo")
        end,
        desc = "Undo opencode change",
      },
      {
        "<leader>or",
        function()
          require("opencode").command("session.redo")
        end,
        desc = "Redo opencode change",
      },
      {
        "<leader>oi",
        function()
          require("opencode").command("session.interrupt")
        end,
        desc = "Interrupt opencode",
      },
      {
        "<leader>op",
        function()
          require("opencode").command("prompt.submit")
        end,
        desc = "Submit opencode prompt",
      },
      {
        "<leader>oc",
        function()
          require("opencode").command("prompt.clear")
        end,
        desc = "Clear opencode prompt",
      },
      {
        "<leader>oU",
        function()
          require("opencode").command("session.half.page.up")
        end,
        desc = "Scroll opencode up",
      },
      {
        "<leader>oD",
        function()
          require("opencode").command("session.half.page.down")
        end,
        desc = "Scroll opencode down",
      },
      {
        "go",
        function()
          return require("opencode").operator("@this ")
        end,
        mode = { "n", "x" },
        expr = true,
        desc = "Add range to opencode",
      },
      {
        "goo",
        function()
          return require("opencode").operator("@this ") .. "_"
        end,
        expr = true,
        desc = "Add line to opencode",
      },
    },
    init = function()
      vim.g.opencode_opts = {
        server = {
          start = function()
            require("snacks.terminal").open("opencode --port", {
              win = { position = "right", width = 0.40, enter = false },
            })
          end,
        },
      }
      vim.o.autoread = true
    end,
  },

  -- Devcontainer management (build, start, stop, attach, exec) like VS Code.
  {
    "ksoichiro/container.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = {
      "ContainerOpen", "ContainerBuild", "ContainerStart",
      "ContainerStop", "ContainerKill", "ContainerRestart",
      "ContainerPicker", "ContainerExec", "ContainerShell",
    },
    config = function()
      require("container").setup({
        auto_open = "off",
        ui = {
          picker = "telescope",
          show_notifications = true,
        },
      })
    end,
  },

  -- Recent project history (auto-tracks directories you work in).
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern" },
        patterns = { ".git", ".vscode", "Makefile", "package.json" },
        scope_chdir = "global",
        silent_chdir = true,
      })
    end,
  },

  -- Telescope is kept as a library for the vs-tasks task picker, the
  -- <leader>fc compile_commands switcher, and the Workspace Hub. The day-to-day
  -- find/grep keymaps live in fzf-lua (see lua/plugins/fzf.lua).
  {
    "nvim-telescope/telescope.nvim",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local fb_actions = require("telescope").extensions.file_browser.actions
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { preview_width = 0.55 },
        },
        extensions = {
          file_browser = {
            grouped = true,
            hidden = true,
            respect_gitignore = false,
            git_status = true,
            hijack_netrw = true,
            mappings = {
              i = {
                ["<C-a>"] = fb_actions.create,
                ["<C-d>"] = fb_actions.remove,
                ["<C-r>"] = fb_actions.rename,
                ["<C-m>"] = fb_actions.move,
              },
              n = {
                ["a"] = fb_actions.create,
                ["d"] = fb_actions.remove,
                ["r"] = fb_actions.rename,
                ["m"] = fb_actions.move,
              },
            },
          },
        },
      })
      telescope.load_extension("fzf")
      telescope.load_extension("file_browser")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "markdown_inline", "TelescopePrompt", "TelescopeResults", "TelescopePreview", "fzf" },
        callback = function(event)
          pcall(vim.treesitter.stop, event.buf)
        end,
        desc = "Disable Treesitter where parser decorations are noisy",
      })

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
          disable = { "markdown", "markdown_inline" },
        },
        indent = {
          enable = true,
        },
      })
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
    "neovim/nvim-lspconfig",
    ft = { "c", "cpp", "python", "rust", "lua", "go", "json", "yaml", "h", "hpp" },
    cmd = { "LspInfo", "LspStop", "LspStart", "LspRestart" },
    config = function()
      local function lsp_client_filter(name)
        if name and name ~= "" then
          return { name = name }
        end

        return {}
      end

      local function lsp_info()
        local lines = {}
        local clients = vim.lsp.get_clients()

        if vim.tbl_isempty(clients) then
          table.insert(lines, "No active LSP clients.")
        else
          for _, client in ipairs(clients) do
            table.insert(lines, string.format("%s [%d]", client.name, client.id))
            if client.config and client.config.cmd then
              table.insert(lines, "  cmd: " .. table.concat(client.config.cmd, " "))
            end
            if client.config and client.config.root_dir then
              table.insert(lines, "  root: " .. client.config.root_dir)
            end
            table.insert(lines, "")
          end
        end

        vim.cmd("botright new")
        local bufnr = vim.api.nvim_get_current_buf()
        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].swapfile = false
        vim.api.nvim_buf_set_name(bufnr, "LspInfo")
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      end

      local function reload_current_buffer()
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(0) then
            vim.cmd("edit")
          end
        end, 100)
      end

      local function clangd_cmd()
        local cmd = { "clangd" }
        local compile_commands_dir = require("config.clangd_build").active(vim.fn.getcwd())
        if compile_commands_dir then
          table.insert(cmd, "--compile-commands-dir=" .. compile_commands_dir)
        end
        return cmd
      end

      vim.api.nvim_create_user_command("LspInfo", lsp_info, {
        desc = "Show active LSP clients",
      })

      vim.api.nvim_create_user_command("LspStop", function(opts)
        for _, client in ipairs(vim.lsp.get_clients(lsp_client_filter(opts.args))) do
          client:stop(true)
        end
      end, {
        complete = function()
          return vim.tbl_map(function(client)
            return client.name
          end, vim.lsp.get_clients())
        end,
        desc = "Stop LSP clients",
        nargs = "?",
      })

      vim.api.nvim_create_user_command("LspStart", function(opts)
        if opts.args == "" or opts.args == "clangd" then
          vim.lsp.config("clangd", { cmd = clangd_cmd() })
          vim.lsp.enable("clangd", true)
        end
        reload_current_buffer()
      end, {
        desc = "Start configured LSP clients",
        nargs = "?",
      })

      vim.api.nvim_create_user_command("LspRestart", function(opts)
        if opts.args == "" or opts.args == "clangd" then
          vim.lsp.config("clangd", { cmd = clangd_cmd() })
          vim.lsp.enable("clangd", true)
        end
        for _, client in ipairs(vim.lsp.get_clients(lsp_client_filter(opts.args))) do
          client:stop(true)
        end
        reload_current_buffer()
      end, {
        complete = function()
          return vim.tbl_map(function(client)
            return client.name
          end, vim.lsp.get_clients())
        end,
        desc = "Restart LSP clients",
        nargs = "?",
      })

      -- Ensure the global clangd config that strips GCC/ARM cross-compile flags
      -- clang doesn't understand (so GCC builds don't produce "Unknown
      -- argument" diagnostics). Written outside any project repo.
      require("config.clangd_config").ensure()

      vim.lsp.config("clangd", {
        cmd = clangd_cmd(),
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

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        delay = 500,
      })
      require("which-key").add({
        { "<leader>d", group = "debug/diagnostics" },
        { "<leader>D", group = "devcontainer (hub/reopen/stop)" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "workspace hub" },
        { "<leader>l", group = "lsp" },
        { "<leader>o", group = "opencode" },
        { "<leader>p", group = "pull request / issues" },
        { "<leader>q", group = "session" },
        { "<leader>t", group = "tasks/terminals" },
        { "<leader>w", group = "window" },
      })
    end,
  },

  {
    "folke/persistence.nvim",
    event = "VimEnter",
    config = function()
      local persistence = require("persistence")
      vim.opt.sessionoptions = { "buffers", "curdir", "folds", "globals", "help", "tabpages", "winsize" }
      persistence.setup()

      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = function()
          vim.cmd("%argdel")

          -- Leave the reusable terminal buffer before saving the session layout.
          pcall(function()
            require("config.terminal").close()
          end)

          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            local is_dir = name ~= "" and vim.fn.isdirectory(name) == 1
            local buftype = vim.bo[buf].buftype
            if vim.api.nvim_buf_is_valid(buf) and (is_dir or buftype == "nofile" or buftype == "terminal" or buftype == "prompt") then
              pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
          end
        end,
      })

      if vim.fn.argc(-1) == 0 and vim.v.this_session == "" then
        vim.schedule(function()
          if vim.v.this_session == "" then
            persistence.load()
          end
        end)
      end

      local map = vim.keymap.set
      map("n", "<leader>qs", function()
        persistence.load()
      end, { desc = "Restore session" })
      map("n", "<leader>ql", function()
        persistence.load({ last = true })
      end, { desc = "Restore last session" })
      map("n", "<leader>qd", function()
        persistence.stop()
      end, { desc = "Do not save session" })
    end,
  },
}
