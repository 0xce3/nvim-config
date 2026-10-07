-- File-based RPC connects the headless editor server to its tmux UI session.
local M = {}

local function directory()
  if vim.env.NVIM_DEV_REMOTE == "1" then
    local workspace = vim.env.NVIM_DEV_CONTAINER_WORKSPACE
    return workspace and vim.fs.joinpath(workspace, ".git", "nvim-tmux")
  end
  return vim.env.NVIM_TMUX_BRIDGE_DIR
end

function M.available()
  local dir = directory()
  local heartbeat = dir and vim.uv.fs_stat(vim.fs.joinpath(dir, "heartbeat"))
  return heartbeat ~= nil and os.time() - heartbeat.mtime.sec < 5
end

function M.request(data, done)
  local dir = directory()
  if not M.available() then return false end
  local stem = vim.fs.joinpath(dir, tostring(vim.fn.getpid()) .. "-" .. tostring(vim.uv.hrtime()))
  local temporary = stem .. ".tmp"
  vim.fn.writefile({ vim.json.encode(data) }, temporary)
  local renamed, error = vim.uv.fs_rename(temporary, stem .. ".request")
  if not renamed then
    vim.notify(tostring(error), vim.log.levels.ERROR, { title = "tmux" })
    return false
  end
  local started = vim.uv.hrtime()
  local function poll()
    if vim.fn.filereadable(stem .. ".response") == 1 then
      local response = table.concat(vim.fn.readfile(stem .. ".response"), "\n")
      vim.fn.delete(stem .. ".response")
      if response ~= "ok" then
        vim.notify(response, vim.log.levels.ERROR, { title = "tmux" })
      end
      if done then done(response == "ok", stem) end
    elseif vim.uv.hrtime() - started > 10e9 then
      vim.fn.delete(stem .. ".request")
      vim.notify("The tmux bridge did not respond", vim.log.levels.ERROR, { title = "tmux" })
      if done then done(false, stem) end
    else
      vim.defer_fn(poll, 100)
    end
  end
  poll()
  return true
end

function M.select(window)
  return M.request({ action = "select", window = window })
end

return M
