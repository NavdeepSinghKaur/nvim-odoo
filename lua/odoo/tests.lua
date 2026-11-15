-- Odoo tests: which test is under the cursor, and what a test run's output means.
local paths = require("odoo.paths")
local M = {}

--- Test tag for the last of `lines` (the lines of a test file up to the cursor):
--- "/module:TestClass.test_method", or just the class, or just the module.
---@param lines string[]
---@param module string
---@return string tag
function M.tag(lines, module)
  local method, class -- method: nil = not found yet, false = inside a method that is not a test
  for i = #lines, 1, -1 do
    local line = lines[i]
    if method == nil then
      local name = line:match("^%s+def ([%w_]+)")
      if name then method = name:match("^test_") and name or false end
    end
    class = line:match("^class ([%w_]+)")
    if class then break end
  end
  if not class then return "/" .. module end
  return "/" .. module .. ":" .. class .. (method and ("." .. method) or "")
end

--- Test tag for the cursor position in the current buffer (nil outside a module).
---@return string? tag, string? module
function M.tag_at_cursor()
  local module = paths.module_of()
  if not module then return nil end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  return M.tag(vim.api.nvim_buf_get_lines(0, 0, row, false), module), module
end

---@class OdooTestResult
---@field failed boolean
---@field summary? string the "N failed, M error(s) of K tests" line of Odoo, when there is one

--- Read the outcome of a test run from its exit code and output.
---@param code integer
---@param lines string[]
---@return OdooTestResult
function M.result(code, lines)
  local summary
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("failed, %d+ error") or line:match("tests? in") then
      summary = line:gsub("^.-: ", "")
      break
    end
  end
  local failed = code ~= 0
  for _, line in ipairs(lines) do
    if line:match("^FAIL:") or line:match("^ERROR:") or line:match(" ERROR .*odoo%.tests") then failed = true end
  end
  return { failed = failed, summary = summary }
end

return M
