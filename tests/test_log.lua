local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["parses a Python traceback frame"] = function()
  local _, root = H.project()
  local log = require("odoo.log")
  local file, lnum = log.parse_location('  File "/mnt/custom/my_mod/models/thing.py", line 12, in create')
  eq(file, root .. "/ws/custom/my_mod/models/thing.py")
  eq(lnum, 12)
end

T["parses an XML parse error and a bare path:line"] = function()
  local _, root = H.project()
  H.write(root .. "/ws/custom/my_mod/views/thing.xml", { "<odoo/>" })
  local log = require("odoo.log")
  local file, lnum = log.parse_location("ParseError: while parsing /mnt/custom/my_mod/views/thing.xml:7, somewhere")
  eq({ file, lnum }, { root .. "/ws/custom/my_mod/views/thing.xml", 7 })
  file, lnum = log.parse_location("see /mnt/custom/my_mod/models/thing.py:3 for details")
  eq({ file, lnum }, { root .. "/ws/custom/my_mod/models/thing.py", 3 })
end

T["ignores lines without a readable file"] = function()
  H.project()
  local log = require("odoo.log")
  eq(log.parse_location("2026-01-01 INFO db odoo.modules.loading: loading 12 modules"), nil)
  eq(log.parse_location('  File "/mnt/custom/my_mod/models/missing.py", line 1, in x'), nil)
end

T["quickfix lists your own code first, then core, then error lines"] = function()
  local _, root = H.project()
  local items = require("odoo.log").to_qf({
    '  File "/usr/lib/python3/dist-packages/odoo/models.py", line 5, in write',
    "    vals = self._prepare(vals)",
    '  File "/mnt/custom/my_mod/models/thing.py", line 1, in write',
    "    raise ValueError('boom')",
    "2026-01-01 10:00:00,000 1 ERROR db odoo.sql_db: bad query",
  })
  eq(#items, 3)
  eq(items[1].filename, root .. "/ws/custom/my_mod/models/thing.py")
  eq(items[1].text, "in write  │ raise ValueError('boom')")
  eq(items[2].filename, root .. "/core/odoo/models.py")
  eq(items[3].filename, nil)
end

return T
