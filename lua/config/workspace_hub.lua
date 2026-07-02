local M = {}

local function get_icon(entry_type)
  if entry_type == "project" then
    return " "
  end
  return "  "
end

function M.get_recent_projects()
  local ok, project_nvim = pcall(require, "project_nvim")
  if not ok then
    return {}
  end
  local history = project_nvim.get_recent_projects()
  if not history or #history == 0 then
    return {}
  end

  local projects = {}
  local seen = {}
  for _, path in ipairs(history) do
    if path and path ~= "" and vim.fn.isdirectory(path) == 1 and not seen[path] then
      seen[path] = true
      table.insert(projects, {
        name = vim.fn.fnamemodify(path, ":t"),
        path = path,
      })
    end
  end

  return projects
end

function M.open(opts)
  opts = opts or {}
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values

  local entries = {}

  local recent_projects = M.get_recent_projects()
  local has_projects = #recent_projects > 0

  if has_projects then
    table.insert(entries, { type = "section", display = "── Recent Projects ──", ordinal = "" })
    for _, p in ipairs(recent_projects) do
      table.insert(entries, {
        type = "project",
        display = "  " .. p.name .. "  " .. p.path,
        ordinal = p.name .. " " .. p.path,
        path = p.path,
        name = p.name,
      })
    end
  end

  if #entries == 0 then
    vim.notify("No recent projects found", vim.log.levels.INFO)
    return
  end

  pickers
    .new({}, {
      prompt_title = "Workspace Hub",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          if entry.type == "section" then
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.ordinal,
              disable = true,
            }
          end
          local icon = get_icon(entry.type)
          return {
            value = entry,
            display = icon .. " " .. entry.display,
            ordinal = entry.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection or selection.value.type == "section" then
            return
          end
          M.handle_selection(selection.value)
        end)
        return true
      end,
    })
    :find()
end

function M.handle_selection(entry)
  if entry.type == "project" then
    vim.api.nvim_set_current_dir(entry.path)
    vim.env.PROJECT_ROOT = entry.path
    vim.env.WORKSPACE_FOLDER = entry.path
    vim.defer_fn(function()
      require("telescope.builtin").find_files({ cwd = entry.path })
    end, 50)
  end
end

function M.toggle()
  M.open()
end

return M
