local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["classifies a path as own, read-only or Odoo"] = function()
  local _, root = H.project()
  local paths = require("odoo.paths")
  eq(paths.is_own(root .. "/ws/custom/my_mod/models/thing.py"), true)
  eq(paths.is_own(root .. "/ws/oca/web/web_responsive/__manifest__.py"), false)
  eq(paths.is_readonly(root .. "/core/odoo/models.py"), true)
  eq(paths.is_readonly(root .. "/ws/custom/my_mod/models/thing.py"), false)
  eq(paths.is_odoo(root .. "/core/odoo/models.py"), true)
  eq(paths.is_odoo(root .. "/elsewhere/file.py"), false)
  eq(paths.is_odoo(""), false)
end

T["a folder name that only shares a prefix is not inside"] = function()
  local _, root = H.project()
  eq(require("odoo.paths").is_own(root .. "/ws/custom_other/x.py"), false)
end

T["finds the module of a file"] = function()
  local _, root = H.project()
  local paths = require("odoo.paths")
  local name, dir = paths.module_of(root .. "/ws/custom/my_mod/models/thing.py")
  eq(name, "my_mod")
  eq(dir, root .. "/ws/custom/my_mod")
  eq(paths.module_of(root .. "/ws/custom/my_mod"), "my_mod")
  eq(paths.module_of(root .. "/docker/compose.yml"), nil)
end

T["translates container paths to local paths and back"] = function()
  local _, root = H.project()
  local paths = require("odoo.paths")
  eq(paths.to_local("/mnt/custom/my_mod/models/thing.py"), root .. "/ws/custom/my_mod/models/thing.py")
  eq(paths.to_remote(root .. "/ws/oca/web/x.py"), "/mnt/oca/web/x.py")
  eq(paths.to_local("/usr/lib/python3/dist-packages/odoo/models.py"), root .. "/core/odoo/models.py")
  eq(paths.to_local("/somewhere/else.py"), "/somewhere/else.py")
end

T["expands a folder of repos into its addons folders"] = function()
  local _, root = H.project()
  local paths = require("odoo.paths")
  eq(paths.addon_dirs(), { root .. "/ws/custom", root .. "/ws/oca/web", root .. "/core/odoo/addons" })
  eq(paths.addon_dir_label(root .. "/ws/oca/web"), "oca/web")
  eq(paths.addon_dir_label(root .. "/core/odoo/addons"), "core")
  eq(paths.addon_dir_label(root .. "/ws/custom"), "custom")
end

return T
