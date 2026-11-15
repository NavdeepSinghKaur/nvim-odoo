local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- Run a shell command in the log panel and wait for it: exit code, collected lines, panel lines.
local function run(script, opts)
  local log = require("odoo.log")
  local code, lines
  log.run(vim.tbl_extend("force", {
    title = "test",
    cmd = { "sh", "-c", script },
    quickfix = false,
    on_exit = function(exit_code, all)
      code, lines = exit_code, all
    end,
  }, opts or {}))
  vim.wait(10000, function() return code ~= nil end)
  local panel = vim.api.nvim_buf_get_lines(vim.fn.bufnr("odoo://test"), 0, -1, false)
  vim.cmd("only")
  return code, lines, panel
end

T["shows the command, its output and the exit code"] = function()
  local code, lines, panel = run("printf 'one\\ntwo\\nlast without newline'; exit 3")
  eq(code, 3)
  eq(lines, { "one", "two", "last without newline" })
  eq(panel[1]:sub(1, 7), "$ sh -c")
  eq(vim.list_slice(panel, 3), { "one", "two", "last without newline", "", "[exit code 3]" })
end

T["keeps only the last lines of output that never ends"] = function()
  local code, lines, panel = run("seq 1 5000", { max_lines = 100 })
  eq(code, 0)
  eq(#panel, 100)
  eq(panel[#panel], "[exit code 0]")
  eq(panel[#panel - 2], "5000")
  eq(#lines <= 200, true)
  eq(lines[#lines], "5000")
end

return T
