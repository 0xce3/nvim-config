return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      { "<leader>oa", function() require("opencode").ask("@buffer: ") end, mode = "n", desc = "Ask opencode about buffer" },
      { "<leader>oa", function() require("opencode").ask("@this: ") end, mode = "x", desc = "Ask opencode about selection" },
      { "<leader>oo", function() require("opencode").select() end, mode = { "n", "x" }, desc = "Select opencode action" },
      { "<leader>on", function() require("opencode").command("session.new") end, desc = "New opencode session" },
      { "<leader>os", function() require("opencode").command("session.select") end, desc = "Select opencode session" },
      { "<leader>ou", function() require("opencode").command("session.undo") end, desc = "Undo opencode change" },
      { "<leader>or", function() require("opencode").command("session.redo") end, desc = "Redo opencode change" },
      { "<leader>oi", function() require("opencode").command("session.interrupt") end, desc = "Interrupt opencode" },
      { "<leader>op", function() require("opencode").command("prompt.submit") end, desc = "Submit opencode prompt" },
      { "<leader>oc", function() require("opencode").command("prompt.clear") end, desc = "Clear opencode prompt" },
      { "<leader>oU", function() require("opencode").command("session.half.page.up") end, desc = "Scroll opencode up" },
      { "<leader>oD", function() require("opencode").command("session.half.page.down") end, desc = "Scroll opencode down" },
      { "go", function() return require("opencode").operator("@this ") end, mode = { "n", "x" }, expr = true, desc = "Add range to opencode" },
      { "goo", function() return require("opencode").operator("@this ") .. "_" end, mode = { "n", "x" }, expr = true, desc = "Add line to opencode" },
    },
    init = function()
      local function project_root()
        return vim.fs.root(0, { ".git" }) or vim.uv.cwd()
      end

      local function project_port(root)
        local hash = 0
        for index = 1, #root do
          hash = (hash * 31 + root:byte(index)) % 10000
        end
        return 4100 + hash
      end

      local root = project_root()
      local port = project_port(root)
      local opencode = vim.fn.exepath("opencode")
      if opencode == "" then opencode = "/home/ubuntu/.opencode/bin/opencode" end
      local function mapped_path(buf)
        local path = vim.api.nvim_buf_get_name(buf)
        local container_root = vim.env.NVIM_DEV_CONTAINER_WORKSPACE
        local host_root = vim.env.NVIM_DEV_HOST_ROOT
        if path ~= "" and container_root and host_root then
          local prefix = container_root:gsub("/$", "") .. "/"
          if path:find(prefix, 1, true) == 1 then return host_root .. "/" .. path:sub(#prefix + 1) end
        end
        return path
      end

      local function format_mapped(context, opts)
        local path = mapped_path(opts.buf or context.buf)
        if path == "" then return nil end
        return require("opencode").format({ path = path, from = opts.from, to = opts.to, rel = context.server.cwd })
      end

      vim.g.opencode_opts = {
        server = {
          url = function(callback) callback("http://127.0.0.1:" .. port) end,
          start = function()
            require("snacks.terminal").open(vim.fn.shellescape(opencode) .. " serve --port " .. port .. " --hostname 127.0.0.1", {
              cwd = root,
              win = { position = "right", enter = false },
            })
          end,
        },
        contexts = {
          ["@this"] = function(context)
            if context.range then
              local from = { context.range.from[1] }
              local to = { context.range.to[1] }
              if context.range.kind ~= "line" then
                from[2] = context.range.from[2] + 1
                to[2] = context.range.to[2] + 1
              end
              return format_mapped(context, { buf = context.buf, from = from, to = to })
            end
            return format_mapped(context, { buf = context.buf, from = { context.cursor[1], context.cursor[2] + 1 } })
          end,
          ["@buffer"] = function(context) return format_mapped(context, { buf = context.buf }) end,
        },
      }
      vim.o.autoread = true
    end,
  },
}
