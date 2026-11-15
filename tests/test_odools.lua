local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["generates the odoo-ls config from the settings"] = function()
  local _, root = H.project()
  local text = table.concat(require("odoo.odools").content(), "\n")
  local function has(s) eq(text:find(s, 1, true) ~= nil, true) end
  has('odoo_path = "' .. root .. '/core"')
  has('  "' .. root .. '/ws/custom",')
  has('  "' .. root .. '/ws/oca/web",')
  has('python_path = "/usr/bin/python3"')
  has('paths = ["' .. root .. '/ws/custom/**"]')
  -- core addons belong to odoo_path, not to addons_paths
  eq(text:find('  "' .. root .. '/core/odoo/addons",', 1, true), nil)
end

return T
