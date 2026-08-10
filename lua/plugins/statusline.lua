-- Customize only the statusline tree. Do not modify AstroUI's shared status
-- component defaults because the buffer tabline derives icons from them.
local ports_cache = { updated = 0, values = {} }

local function forwarded_ports()
  local now = vim.uv.now()
  if now - ports_cache.updated < 1000 then return ports_cache.values end
  ports_cache.updated = now

  local workspace = vim.env.NVIM_DEV_CONTAINER_WORKSPACE
  if not workspace or workspace == "" then
    ports_cache.values = {}
    return ports_cache.values
  end
  local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(workspace, ".git", "nvim-forwarded-ports"))
  ports_cache.values = ok and vim.tbl_filter(function(port) return port:match("^%d+$") ~= nil end, lines) or {}
  return ports_cache.values
end

local function show_forwarded_ports()
  local ports = forwarded_ports()
  if #ports == 0 then
    vim.notify("No forwarded ports", vim.log.levels.INFO, { title = "Devcontainer Ports" })
    return
  end

  local lines = vim.tbl_map(function(port)
    if port == "443" or port == "8443" then return "https://localhost:" .. port end
    if port == "22" or port == "10022" then return "ssh -p " .. port .. " localhost" end
    return "http://localhost:" .. port
  end, ports)
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Devcontainer Ports" })
end

return {
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      local status = require("astroui.status")

      vim.api.nvim_create_user_command("ForwardedPorts", show_forwarded_ports, {
        desc = "Show forwarded devcontainer ports",
        force = true,
      })
      vim.keymap.set("n", "<leader>tp", show_forwarded_ports, { desc = "Show forwarded ports" })

      if vim.env.NVIM_DEV_REMOTE == "1" then
        local timer = vim.uv.new_timer()
        timer:start(2000, 2000, vim.schedule_wrap(function()
          if vim.v.exiting == 0 then vim.cmd.redrawstatus() end
        end))
        vim.api.nvim_create_autocmd("VimLeavePre", {
          once = true,
          callback = function()
            if not timer:is_closing() then timer:stop(); timer:close() end
          end,
        })
      end

      opts.statusline[3] = status.component.file_info {
        file_icon = false,
        filetype = false,
      }
      opts.statusline[9] = status.component.lsp {
        lsp_client_names = {
          mappings = {
            clangd = function()
              local dir = vim.env.NVIM_CLANGD_COMPILE_COMMANDS_DIR
              if not dir or dir == "" then
                local ok, store = pcall(require, "config.clangd_build")
                if ok then dir = store.active(vim.fn.getcwd()) end
              end
              return dir and vim.fn.fnamemodify(dir, ":t") or "clangd"
            end,
          },
        },
      }
      table.insert(opts.statusline, 9, status.component.builder {
        condition = function()
          local terminal = require("config.terminal")
          return terminal.task_status() ~= nil or terminal.is_task_running() or terminal.is_debug_waiting()
        end,
        {
          provider = function()
            return require("astroui").get_icon("Package", 1, true)
          end,
          hl = { fg = "#ebdbb2" },
        },
        {
          provider = function()
            local terminal = require("config.terminal")
            return (terminal.is_debug_waiting() and "DAP: " .. terminal.debug_wait_label() or "Task: " .. (terminal.task_label() or "Task")) .. " "
          end,
          hl = { fg = "#ebdbb2" },
        },
        {
          provider = function()
            local terminal = require("config.terminal")
            if terminal.is_debug_waiting() then return "waiting " .. terminal.task_spinner() end
            local task_status = terminal.task_status()
            if task_status == "success" then return "successful" end
            if task_status == "failed" then return "failed" end
            return "running " .. terminal.task_spinner()
          end,
          hl = function()
            local task_status = require("config.terminal").task_status()
            if task_status == "success" then return { fg = "#b8bb26", bold = true } end
            if task_status == "failed" then return { fg = "#fb4934", bold = true } end
            return { fg = "#fabd2f", bold = true }
          end,
        },
        surround = { separator = "right" },
      })
      table.insert(opts.statusline, 9, status.component.builder {
        condition = function() return #forwarded_ports() > 0 end,
        {
          provider = function() return require("astroui").get_icon("Ports", 1, true) end,
          hl = { fg = "#83a598" },
        },
        {
          provider = function()
            local ports = forwarded_ports()
            local shown = { ports[1] }
            if ports[2] then shown[#shown + 1] = ports[2] end
            local suffix = #ports > 2 and ", +" .. (#ports - 2) or ""
            return "Ports: " .. table.concat(shown, ", ") .. suffix
          end,
          hl = { fg = "#83a598", bold = true },
        },
        on_click = {
          name = "heirline_forwarded_ports",
          callback = show_forwarded_ports,
        },
        surround = { separator = "right" },
      })
      table.insert(opts.statusline, 2, status.component.builder {
        {
          provider = function()
            local remote = vim.env.NVIM_DEV_REMOTE == "1"
            return status.utils.stylize(remote and "remote" or "local", {
              icon = { kind = remote and "Remote" or "Local", padding = { right = 1 } },
              padding = { right = 1 },
            })
          end,
        },
        { provider = "|" },
        hl = status.hl.get_attributes "git_branch",
        surround = { separator = "left", color = "git_branch_bg" },
      })
    end,
  },
}
