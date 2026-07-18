require("config.options")
require("config.keymaps")
require("config.filetypes")
require("config.format_specifiers").setup()
require("config.preproc").setup()
require("config.inactive_regions").setup()
require("config.skeleton").setup()
require("config.http_workspace").setup()
require("config.lazy")



-- Workspace hub is opened manually via <leader>hh or the `h` key on
-- the Snacks dashboard. No auto-open during startup to avoid any IO.
