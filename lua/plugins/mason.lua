-- Customize Mason

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
      ensure_installed = {
        -- install language servers
        "clangd",
        "lua-language-server",

        -- install formatters
        "stylua",

        -- install any other package
        -- Newer release binaries require glibc 2.39 and fail on Ubuntu 22.04 devcontainers.
        "tree-sitter-cli@v0.25.10",
      },
    },
  },
}
