local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- An addon `shop` with the files given; returns its folder.
---@param files table<string, string[]> path inside the addon -> lines
local function addon(files)
  local root = H.tmpdir()
  for path, lines in pairs(files) do
    H.write(root .. "/shop/" .. path, lines)
  end
  return root .. "/shop"
end

local MANIFEST = {
  "{",
  '    "name": "Shop",',
  '    "assets": {',
  '        "web.assets_backend": [',
  '            "shop/static/src/cart.esm.js",',
  '            "shop/static/src/cart.xml",',
  '            "shop/static/src/fields/**/*",',
  "        ],",
  "    },",
  "}",
}

--- "severity:text" of every problem
local function summary(dir)
  return vim.tbl_map(function(p) return p.severity .. ":" .. p.text end, require("odoo.frontend").check(dir))
end

T["a consistent addon has no problems"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = MANIFEST,
    ["static/src/cart.esm.js"] = {
      'import { Component } from "@odoo/owl";',
      'class Cart { static template = "shop.Cart"; }',
    },
    ["static/src/cart.xml"] = { '<t t-name="shop.Cart"/>' },
    ["static/src/fields/a/b.scss"] = { ".a {}" },
  })
  eq(summary(dir), {})
end

T["a file no bundle loads is an error"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = MANIFEST,
    ["static/src/orphan.scss"] = { ".a {}" },
    ["static/src/cart.esm.js"] = {},
    ["static/src/cart.xml"] = {},
  })
  eq(summary(dir), {
    "error:no bundle in __manifest__.py loads this file (add it under 'assets')",
    "warn:the pattern 'shop/static/src/fields/**/*' matches no file",
  })
end

T["a bundle entry without a file is an error, a pattern without files a warning"] = function()
  H.project()
  local dir = addon({ ["__manifest__.py"] = MANIFEST })
  eq(summary(dir), {
    "error:the bundle lists 'shop/static/src/cart.esm.js' but the file does not exist",
    "error:the bundle lists 'shop/static/src/cart.xml' but the file does not exist",
    "warn:the pattern 'shop/static/src/fields/**/*' matches no file",
  })
end

T["entries of other modules and removed entries are not checked"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = {
      '{"assets": {"web.assets_backend": [',
      '  ("remove", "shop/static/src/gone.js"), "web/static/src/core.js", # comment "shop/static/src/x.js"',
      "]}}",
    },
  })
  eq(summary(dir), {})
end

T["a template without t-name is an error, one of another module is not"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = MANIFEST,
    ["static/src/cart.esm.js"] = { 'static template = "shop.Missing";', "static template = 'web.Core';" },
    ["static/src/cart.xml"] = { "<templates/>" },
  })
  eq(summary(dir), {
    "error:template 'shop.Missing' has no t-name in this module's XML files",
    "warn:the pattern 'shop/static/src/fields/**/*' matches no file",
  })
end

T["legacy odoo.define and require('web.') are warnings"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = MANIFEST,
    ["static/src/cart.esm.js"] = {
      "odoo.define('shop.cart', function (require) {",
      "  var core = require('web.core');",
    },
    ["static/src/cart.xml"] = {},
    ["static/src/fields/x.js"] = {},
  })
  eq(#summary(dir), 2)
end

T["manifest styles seen in OCA: split strings, leading slash, directive tuples"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = {
      '{"assets": {"web.assets_backend": [',
      '  "shop/static/src/components/"',
      '  "a/a.esm.js",',
      '  "/shop/static/src/b.scss",',
      '  ("after", "/web/static/src/x.js", "/shop/static/src/c.xml"),',
      "]}}",
    },
    ["static/src/components/a/a.esm.js"] = {},
    ["static/src/b.scss"] = {},
    ["static/src/c.xml"] = {},
  })
  eq(summary(dir), {})
end

T["a file a report XML links to is not an orphan"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = { '{"assets": {}}' },
    ["static/src/css/report.css"] = {},
    ["report/layout.xml"] = { '<link href="/shop/static/src/css/report.css"/>' },
  })
  eq(summary(dir), {})
end

T["the lib folder is not checked"] = function()
  H.project()
  local dir = addon({
    ["__manifest__.py"] = { '{"assets": {}}' },
    ["static/src/lib/big.min.js"] = { "odoo.define(" },
  })
  eq(summary(dir), {})
end

T["odoo-nvim frontend fails on errors and passes on a clean addon"] = function()
  local _, root = H.project()
  H.write(root .. "/ws/custom/my_mod/static/src/lost.js", { "" })
  assert(require("odoo.detect").write({ workspace = root .. "/ws", core = root .. "/core" }, root .. "/local.lua"))
  vim.env.ODOO_NVIM_SETTINGS = root .. "/local.lua"
  local bad = vim.system({ "scripts/odoo-nvim", "frontend", "my_mod" }, { text = true }):wait()
  eq(bad.code, 1)
  eq(bad.stdout:find("RESULT: failed frontend my_mod (1 error(s), 0 warning(s))", 1, true) ~= nil, true)
  os.remove(root .. "/ws/custom/my_mod/static/src/lost.js")
  local good = vim.system({ "scripts/odoo-nvim", "frontend" }, { text = true }):wait()
  eq(good.code, 0)
end

return T
