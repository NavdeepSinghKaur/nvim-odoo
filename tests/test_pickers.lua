local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local MODEL_ARGS = { "-t", "py", "-e", [[_name\s*=]] }

--- Scan for models and wait for the answer: the model lines found, sorted.
local function scan(pickers, dirs)
  local found
  pickers.scan("models", MODEL_ARGS, dirs, function(matches) found = matches end)
  vim.wait(5000, function() return found ~= nil end)
  local texts = vim.tbl_map(function(match) return vim.trim(match.text) end, found)
  table.sort(texts)
  return texts
end

T["a save rescans only the addons folder of the saved file"] = function()
  local _, root = H.project()
  -- selene: allow(global_usage)
  ---@diagnostic disable-next-line: missing-fields
  _G.Snacks = { notifier = { hide = function() end } }
  local own, core = root .. "/ws/custom", root .. "/core/odoo/addons"
  H.write(own .. "/my_mod/models/thing.py", { "    _name = 'my.thing'" })
  H.write(core .. "/sale/models/sale.py", { "    _name = 'sale.order'" })
  local pickers = require("odoo.pickers")
  eq(scan(pickers, { own, core }), { "_name = 'my.thing'", "_name = 'sale.order'" })

  -- both files change on disk, but only the own folder is marked as changed
  H.write(own .. "/my_mod/models/thing.py", { "    _name = 'my.renamed'" })
  H.write(core .. "/sale/models/sale.py", { "    _name = 'sale.changed'" })
  pickers.clear_cache(own)
  eq(scan(pickers, { own, core }), { "_name = 'my.renamed'", "_name = 'sale.order'" })

  pickers.clear_cache()
  eq(scan(pickers, { own, core }), { "_name = 'my.renamed'", "_name = 'sale.changed'" })
end

return T
