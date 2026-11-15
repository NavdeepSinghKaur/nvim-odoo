local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["fills the defaults around the user's values"] = function()
  local settings, root = H.project()
  eq(settings.configured, true)
  eq(settings.problems, {})
  eq(settings.core_addons, root .. "/core/odoo/addons")
  eq(settings.addons_paths[#settings.addons_paths], root .. "/core/odoo/addons") -- core is always searched
  eq(settings.service, "odoo")
  eq(settings.debug, { host = "127.0.0.1", port = 5678, extra_args = { "--dev=xml" } })
  eq(settings.db, nil)
end

T["expands ~ in paths"] = function()
  local settings = H.project({ python = "~/venv/bin/python" })
  eq(settings.python, vim.fs.normalize(vim.env.HOME .. "/venv/bin/python"))
end

T["reports every problem at once and falls back to defaults"] = function()
  local settings, root = H.project({ servce = "web", db_service = 5, own_addons = { "/nowhere/custom" } })
  eq(settings.problems, {
    "'db_service' must be a string, not a number (using the default)",
    "unknown setting 'servce' (see lua/odoo/local.example.lua)",
    "own_addons: no such folder: /nowhere/custom",
  })
  eq(settings.db_service, "db")
  eq(settings.workspace, root .. "/ws")
end

return T
