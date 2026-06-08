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
          Comment    = { fg = "#928374", bg = "NONE", italic = false },
          String     = { fg = "#b8bb26", bg = "NONE", italic = false },
          ["@comment"] = { fg = "#928374", bg = "NONE", italic = false },
          ["@string"] = { fg = "#b8bb26", bg = "NONE", italic = false },
          ["@string.special.path"] = { fg = "#b8bb26", bg = "NONE" },
          cIncluded  = { fg = "#b8bb26", bg = "NONE" },
          Search     = { fg = "#ebdbb2", bg = "#504945", reverse = false },
          IncSearch  = { fg = "#282828", bg = "#fabd2f", reverse = false },
          CurSearch  = { fg = "#282828", bg = "#fabd2f", reverse = false },
          Visual     = { bg = "#504945", reverse = false },
        },
      })

      vim.o.background = "dark"
      vim.cmd.colorscheme("gruvbox")

      local function apply_gruvbox_fixes()
        vim.api.nvim_set_hl(0, "Comment", { fg = "#928374", bg = "NONE", italic = false })
        vim.api.nvim_set_hl(0, "String", { fg = "#b8bb26", bg = "NONE", italic = false })
        vim.api.nvim_set_hl(0, "@comment", { fg = "#928374", bg = "NONE", italic = false })
        vim.api.nvim_set_hl(0, "@string", { fg = "#b8bb26", bg = "NONE", italic = false })
        vim.api.nvim_set_hl(0, "@string.special.path", { fg = "#b8bb26", bg = "NONE", italic = false, underline = false })
        vim.api.nvim_set_hl(0, "cIncluded", { fg = "#b8bb26", bg = "NONE", italic = false })
        vim.api.nvim_set_hl(0, "Search", { fg = "#ebdbb2", bg = "#504945", reverse = false })
        vim.api.nvim_set_hl(0, "IncSearch", { fg = "#282828", bg = "#fabd2f", reverse = false })
        vim.api.nvim_set_hl(0, "CurSearch", { fg = "#282828", bg = "#fabd2f", reverse = false })
        vim.api.nvim_set_hl(0, "Visual", { bg = "#504945", reverse = false })
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
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      vim.api.nvim_set_hl(0, "NeoTreeGitAdded",       { fg = "#b8bb26" })
      vim.api.nvim_set_hl(0, "NeoTreeGitUntracked",   { fg = "#b8bb26" })
      vim.api.nvim_set_hl(0, "NeoTreeGitModified",    { fg = "#fe8019" })
      vim.api.nvim_set_hl(0, "NeoTreeGitUnstaged",    { fg = "#fe8019" })
      vim.api.nvim_set_hl(0, "NeoTreeGitStaged",      { fg = "#fe8019" })
      vim.api.nvim_set_hl(0, "NeoTreeGitIgnored",     { fg = "#928374" })
      vim.api.nvim_set_hl(0, "NeoTreeGitDeleted",     { fg = "#fb4934" })
      vim.api.nvim_set_hl(0, "NeoTreeGitConflict",    { fg = "#fb4934" })
      vim.api.nvim_set_hl(0, "NeoTreeDirectoryIcon",  { fg = "#a89984" })
      vim.api.nvim_set_hl(0, "NeoTreeDirectoryName",  { fg = "#ebdbb2" })
      vim.api.nvim_set_hl(0, "NeoTreeRootName",       { fg = "#ebdbb2", bg = "#32302f", bold = true })
      vim.api.nvim_set_hl(0, "NeoTreeFileIcon", { fg = "#a89984" })

      local neo_tree_components = require("neo-tree.sources.common.components")

      require("neo-tree").setup({
        close_if_last_window = false,
        window = {
          width = 34,
          position = "left",
        },
        filesystem = {
          components = {
            name = function(config, node, state)
              if node:get_depth() == 1 and node.type ~= "message" then
                local name = vim.fn.fnamemodify(node.path or node.name, ":t")
                if name == "" then
                  name = node.name
                end
                if state.current_position == "current" and state.sort and state.sort.label == "Name" then
                  local icon = state.sort.direction == 1 and "▲" or "▼"
                  name = name .. "  " .. icon
                end
                return {
                  text = name,
                  highlight = "NeoTreeRootName",
                }
              end
              return neo_tree_components.name(config, node, state)
            end,
          },
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
          follow_current_file = {
            enabled = true,
          },
        },
        default_component_configs = {
          indent = {
            indent_size = 2,
            with_markers = false,
            with_expanders = false,
          },
          icon = {
            folder_closed = ">",
            folder_open   = "v",
            folder_empty  = ">",
            default       = " ",
          },
          modified = {
            symbol = "●",
          },
          git_status = {
            symbols = {
              added     = "",
              modified  = "",
              deleted   = "",
              renamed   = "",
              untracked = "",
              ignored   = "",
              unstaged  = "",
              staged    = "",
              conflict  = "",
            },
          },
        },
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.schedule(function()
            if vim.fn.exists(":Neotree") ~= 2 then
              return
            end

            local current_win = vim.api.nvim_get_current_win()
            pcall(require("neo-tree.command").execute, { action = "focus" })
            if vim.api.nvim_win_is_valid(current_win) then
              pcall(vim.api.nvim_set_current_win, current_win)
            end
          end)
        end,
      })

      local function focus_project_explorer()
        require("neo-tree.command").execute({
          action = "focus",
          source = "filesystem",
          dir = vim.uv.cwd(),
        })
      end

      vim.keymap.set("n", "<leader>e", focus_project_explorer, { desc = "Explorer project root" })
      vim.keymap.set("n", "<leader>E", "<cmd>Neotree close<cr>", { desc = "Close explorer" })
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
      require("lualine").setup({
        options = {
          theme = "gruvbox",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },

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
      local colors = require("gruvbox").palette
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
              filetype = "neo-tree",
              text = "Explorer",
              text_align = "left",
              separator = true,
            },
          },
        },
        highlights = {
          fill = {
            bg = colors.dark0_soft,
          },
          background = {
            bg = colors.dark0_soft,
          },
          buffer_visible = {
            bg = colors.dark0_soft,
          },
          buffer_selected = {
            fg = colors.light1,
            bg = colors.dark1,
            bold = true,
            italic = false,
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

        -- Prefer WEST_WORKSPACE env var (set in devcontainer) to avoid /workspaces path
        local west_ws = vim.env.WEST_WORKSPACE
        if west_ws and west_ws ~= "" then
          local ws_project = vim.fs.joinpath(west_ws, project_name)
          if vim.fn.isdirectory(ws_project) == 1 then
            return ws_project
          end
        end

        if vim.fn.executable("west") == 1 and vim.system({ "west", "topdir" }, { cwd = cwd }):wait().code == 0 then
          return cwd
        end

        local home_workspace = vim.fs.joinpath(vim.env.HOME or "", "west_workspace", project_name)
        if vim.fn.isdirectory(home_workspace) == 1 then
          return home_workspace
        end

        local matches = vim.fs.find({ ".vscode", ".git", ".west" }, { upward = true, path = cwd })
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

      local pyenv_activate = (vim.env.VIRTUAL_ENV or "/home/user/west_workspace/.pyEnv") .. "/bin/activate"

      local clean_command = vstask_job.clean_command
      vstask_job.clean_command = function(command, options)
        local cleaned = expand_vscode_vars(clean_command(command, options))
        if type(options) == "table" and type(options.env) == "table" then
          local exports = {}
          for key, value in pairs(options.env) do
            table.insert(exports, "export " .. key .. "=" .. vim.fn.shellescape(expand_vscode_vars(value)))
          end
          if #exports > 0 then
            cleaned = table.concat(exports, "; ") .. "; " .. cleaned
          end
        end
        local activate = ". " .. vim.fn.shellescape(pyenv_activate) .. " 2>/dev/null"
        if type(options) == "table" and type(options.cwd) == "string" then
          return activate .. " && { " .. cleaned .. "; }"
        end
        return activate .. " && cd " .. vim.fn.shellescape(task_root) .. " && { " .. cleaned .. "; }"
      end

      local task_terminals = {}

      vstask_job.start_job = function(opts)
        if opts == nil or opts.terminal == false then
          return
        end

        local label = opts.label or "task"
        local command = opts.command

        local existing = task_terminals[label]
        if existing then
          pcall(function() existing:shutdown() end)
          task_terminals[label] = nil
        end

        local Terminal = require("toggleterm.terminal").Terminal
        local term = Terminal:new({
          cmd = command,
          direction = "horizontal",
          close_on_exit = false,
          display_name = label,
          hidden = true,
          on_exit = function(t, _, exit_code, _)
            vim.schedule(function()
              local icon = exit_code == 0 and "✓" or "✗"
              vim.notify(
                string.format("[%s] %s exited %d — press q to close terminal", icon, label, exit_code),
                exit_code == 0 and vim.log.levels.INFO or vim.log.levels.WARN,
                { title = "task" }
              )
              local bufnr = t.bufnr
              if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                vim.keymap.set("n", "q", function()
                  t:close()
                  task_terminals[label] = nil
                end, { buffer = bufnr, nowait = true, silent = true, desc = "Close task terminal" })
                vim.keymap.set("n", "<CR>", function()
                  t:close()
                  task_terminals[label] = nil
                end, { buffer = bufnr, nowait = true, silent = true, desc = "Close task terminal" })
              end
            end)
          end,
        })
        task_terminals[label] = term
        term:open()
      end

      local function pick_terminal()
        local terms = require("toggleterm.terminal").get_all(true)
        if #terms == 0 then
          vim.notify("No terminals open", vim.log.levels.INFO)
          return
        end
        local items = {}
        for _, t in ipairs(terms) do
          table.insert(items, t)
        end
        vim.ui.select(items, {
          prompt = "Switch terminal",
          format_item = function(t)
            return string.format("[%d] %s", t.id, t.display_name or ("Terminal " .. t.id))
          end,
        }, function(choice)
          if choice then
            choice:open()
          end
        end)
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
      map("n", "<leader>tj", pick_terminal, { desc = "Switch terminal" })
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
      require("octo").setup({
        use_local_fs = true,
      })

      local map = vim.keymap.set
      map("n", "<leader>pr",  "<cmd>Octo pr list<cr>",     { desc = "List PRs" })
      map("n", "<leader>prc", "<cmd>Octo pr create<cr>",   { desc = "Create PR" })
      map("n", "<leader>prr", "<cmd>Octo review start<cr>", { desc = "Start PR review" })
      map("n", "<leader>pi",  "<cmd>Octo issue list<cr>",  { desc = "List issues" })
    end,
  },

  {
    "nickjvandyke/opencode.nvim",
    version = "*",
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
      vim.g.opencode_opts = {}
      vim.o.autoread = true
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
        local configured_dir = vim.env.NVIM_CLANGD_COMPILE_COMMANDS_DIR
        if configured_dir and configured_dir ~= "" then
          local configured_path = configured_dir .. "/compile_commands.json"
          if vim.fn.filereadable(configured_path) == 1 then
            return configured_dir
          end
        end

        local candidates = {
          "main_app/build_native_clang",
          "main_app/build_native_gcc",
          "main_app/build",
          "main_app/build_native_clang_debug",
          "build_native_clang_debug",
          "build",
          "build/debug",
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

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        delay = 500,
      })
      require("which-key").add({
        { "<leader>d", group = "debug/diagnostics" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>l", group = "lsp" },
        { "<leader>o", group = "opencode" },
        { "<leader>p", group = "pull request" },
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
      vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize" }
      persistence.setup()

      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = function()
          vim.cmd("%argdel")

          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "neo-tree" and vim.api.nvim_win_is_valid(win) then
              pcall(vim.api.nvim_win_close, win, true)
            end
          end

          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            local is_neotree = vim.bo[buf].filetype == "neo-tree" or name:match("^neo%-tree filesystem")
            local is_dir = name ~= "" and vim.fn.isdirectory(name) == 1
            if vim.api.nvim_buf_is_valid(buf) and (is_neotree or is_dir) then
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
