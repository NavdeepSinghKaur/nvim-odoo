local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local source = {
  "from odoo.tests import TransactionCase",
  "",
  "class TestThing(TransactionCase):",
  "    def setUp(self):",
  "        super().setUp()",
  "",
  "    def test_create(self):",
  "        self.assertTrue(True)",
  "",
  "    def _helper(self):",
  "        return 1",
}

--- Test tag with the cursor on `row` of a test file in my_mod.
local function tag_at(row)
  local _, root = H.project()
  local file = root .. "/ws/custom/my_mod/tests/test_thing.py"
  H.write(file, source)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  local tag, module = require("odoo.tests").tag_at_cursor()
  vim.cmd("bwipeout!")
  return tag, module
end

T["cursor in a test method selects that method"] = function()
  local tag, module = tag_at(8)
  eq(tag, "/my_mod:TestThing.test_create")
  eq(module, "my_mod")
end

T["cursor in a helper method or the class header selects the class"] = function()
  eq(tag_at(11), "/my_mod:TestThing")
  eq(tag_at(5), "/my_mod:TestThing")
  eq(tag_at(3), "/my_mod:TestThing")
end

T["cursor above every class selects the module"] = function() eq(tag_at(1), "/my_mod") end

T["reads the outcome of a test run"] = function()
  local tests = require("odoo.tests")
  local passed = tests.result(0, { "2026-01-01 INFO db odoo.tests.stats: my_mod: 4 tests 0.5s 80 queries", "x" })
  eq(passed.failed, false)
  local failed = tests.result(0, {
    "FAIL: TestThing.test_create",
    "2026-01-01 10:00:00,000 1 ERROR db odoo.tests.result: 1 failed, 0 error(s) of 4 tests when loading database 'db'",
  })
  eq(failed.failed, true)
  eq(failed.summary, "1 failed, 0 error(s) of 4 tests when loading database 'db'")
  eq(tests.result(1, {}).failed, true)
end

return T
