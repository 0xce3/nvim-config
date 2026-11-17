return {
  "neovim/nvim-lspconfig",
  cmd = function(_, commands)
    commands = commands or {}
    table.insert(commands, "LspRestart")
    return commands
  end,
  -- Install after the plugin's commands so lazy loading cannot overwrite it.
  config = function()
    local function restartable_names(prefix)
      local names = {}
      for _, client in ipairs(vim.lsp.get_clients()) do
        -- In-process clients such as opencode_ask_cmp have no named LSP config.
        if vim.lsp.config[client.name] and client.name:sub(1, #prefix) == prefix then
          names[client.name] = true
        end
      end
      local result = vim.tbl_keys(names)
      table.sort(result)
      return result
    end

    vim.api.nvim_create_user_command("LspRestart", function(info)
      local names = info.fargs
      if #names == 0 then names = restartable_names("") end
      for _, name in ipairs(names) do
        if not vim.lsp.config[name] then
          vim.notify(("No restartable LSP configuration for '%s'"):format(name), vim.log.levels.WARN)
          return
        end
      end
      if #names == 0 then return end

      for _, name in ipairs(names) do
        vim.lsp.enable(name, false)
        if info.bang then
          for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
            client:stop(true)
          end
        end
      end
      vim.defer_fn(function()
        for _, name in ipairs(names) do
          vim.lsp.enable(name)
        end
      end, 500)
    end, {
      desc = "Restart configured language servers, excluding internal plugin clients",
      nargs = "?",
      bang = true,
      complete = restartable_names,
    })
  end,
}
