-- ============================================================================
--  Neovim config for Odoo development
--  Lives in ~/odoo/nvim  (symlinked to ~/.config/nvim)
--
--  Read README.md in this folder for the cheat sheet, or press <Space>? in nvim.
--  Press <Space> and wait: a menu shows every shortcut.
-- ============================================================================

-- Leader key = Space. Most custom shortcuts start with it.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")  -- editor behaviour (line numbers, tabs, clipboard...)
require("config.lazy")     -- plugin manager + all plugins in lua/plugins/
require("config.keymaps")  -- general shortcuts (VSCode-like ones too)
require("config.autocmds") -- automatic actions (highlight yank, per-filetype tweaks)
require("odoo").setup()    -- Odoo commands: :Odoo update/test/debug/logs...
