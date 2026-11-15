-- ============================================================================
--  YOUR Odoo setup. Copy to lua/odoo/local.lua (or run :Odoo config) and edit.
--  local.lua is git-ignored. Every key is optional; defaults are in settings.lua.
--  Restart nvim after editing.   Check the result with  :Odoo info
-- ============================================================================
local root = "~/odoo" -- just a helper for the paths below

return {
  -- The repo you work in (language-server workspace, git watcher)
  workspace = root .. "/my-addons",

  -- Code YOU write (black on save, diagnostics). Default: the workspace
  own_addons = { root .. "/my-addons/custom" },

  -- Odoo core: the folder that contains odoo/ (odoo-bin's folder for a source install).
  -- Docker users: leave the default and run :Odoo sync-core to copy it out of the image.
  -- core = root .. "/odoo",

  -- Every addons folder, same as addons_path in odoo.conf but with local paths.
  -- A folder full of repos (oca/web, oca/server-tools...) can be given as one entry.
  addons_paths = {
    root .. "/my-addons/custom",
    root .. "/my-addons/oca",
    -- root .. "/enterprise",
  },

  -- Code you only read (warning before saving). Default: only the core
  readonly_paths = { root .. "/my-addons/oca" },

  -- Python with Odoo's requirements installed (better completion). Default: python3
  -- python = "~/.venvs/odoo/bin/python",

  -- ---------------------------------------------------------------- docker
  compose_dir = root .. "/docker", -- folder with docker-compose.yml
  service = "odoo", -- odoo service name
  db_service = "db", -- postgres service name
  -- odoo_conf = "/etc/odoo/odoo.conf",
  -- db_user = "odoo",
  -- db = "mydb",                  -- default: the -d in the compose `command:`
  -- web_url = "http://localhost:8069",
  -- debug = { port = 5678, extra_args = { "--dev=xml" } },

  -- Container path -> local path. Default: the volumes of the odoo service in the compose file.
  -- path_mappings = {
  --   { remote = "/mnt/extra-addons", ["local"] = root .. "/my-addons/custom" },
  -- },
}
