return {
  {
    "nickjvandyke/opencode.nvim",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      { "<leader>oa", function() require("opencode").ask("@buffer: ") end, mode = "n", desc = "Ask opencode about buffer" },
      { "<leader>oa", function() require("opencode").ask("@this: ") end, mode = "x", desc = "Ask opencode about selection" },
      { "<leader>oo", function() require("opencode").select() end, mode = { "n", "x" }, desc = "Select opencode action" },
      { "go", function() return require("opencode").operator("@this ") end, mode = { "n", "x" }, expr = true, desc = "Add range to opencode" },
      { "goo", function() return require("opencode").operator("@this ") .. "_" end, mode = { "n", "x" }, expr = true, desc = "Add line to opencode" },
    },
    init = function()
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
        local cwd = vim.fn.getcwd()
        local container_root = vim.env.NVIM_DEV_CONTAINER_WORKSPACE
        local host_root = vim.env.NVIM_DEV_HOST_ROOT
        if container_root and host_root then
          container_root = container_root:gsub("/$", "")
          if cwd == container_root or cwd:sub(1, #container_root + 1) == container_root .. "/" then
            cwd = host_root:gsub("/$", "") .. cwd:sub(#container_root + 1)
          end
        end
        return require("opencode").format({ path = path, from = opts.from, to = opts.to, rel = cwd })
      end

      -- The V2 service stores sessions under the host project directory, not
      -- the devcontainer mount path. Keep session lookup aligned with @buffer.
      if vim.env.NVIM_DEV_CONTAINER_WORKSPACE and vim.env.NVIM_DEV_HOST_ROOT then
        local server = require("opencode.server")
        server.get_sessions = function(self)
          local cwd = vim.fn.getcwd()
          local container_root = vim.env.NVIM_DEV_CONTAINER_WORKSPACE:gsub("/$", "")
          local host_root = vim.env.NVIM_DEV_HOST_ROOT:gsub("/$", "")
          if cwd ~= container_root and cwd:sub(1, #container_root + 1) ~= container_root .. "/" then
            return require("opencode.promise").reject("OpenCode: directory is outside the devcontainer workspace")
          end
          local directory = host_root .. cwd:sub(#container_root + 1)
          local path = "/api/session?directory=" .. vim.uri_encode(directory) .. "&order=desc&parentID=null"
          return self:request(path, "GET"):next(function(response)
            return require("opencode.promise").resolve(response and response.data or {})
          end)
        end
      end

      vim.g.opencode_opts = {
        server = {
          url = vim.env.OPENCODE_SERVER_URL,
          start = false,
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
