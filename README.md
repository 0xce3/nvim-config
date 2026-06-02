# Neovim config

Personal Neovim configuration for a devcontainer-based development workflow.

## Restore in a fresh container

```sh
git clone https://github.com/0xce3/nvim-config.git ~/.config/nvim
nvim
```

`lazy.nvim` bootstraps itself on first start and installs the configured plugins.

## Current focus

- GitHub PR interaction through `octo.nvim`
- C/C++ highlighting and diagnostics through Treesitter and `clangd`
- Git workflow through Fugitive and Gitsigns
- Integrated terminal through ToggleTerm
