-- The output of the last update / install / test, kept in a file with local paths, so it can
-- be handed to an AI assistant (<Space>al) or read again from a terminal (`odoo-nvim last`).
local traceback = require("odoo.traceback")
local M = {}

---@return string
function M.file() return vim.fn.stdpath("state") .. "/odoo/last-run.log" end

---@param cmd string[]
---@param lines string[] output, with container paths
---@param code integer exit code
function M.save(cmd, lines, code)
  local content = { "$ " .. table.concat(cmd, " "), "" }
  vim.list_extend(content, vim.tbl_map(traceback.localize, lines))
  vim.list_extend(content, { "", ("[exit code %d]"):format(code) })
  vim.fn.mkdir(vim.fs.dirname(M.file()), "p")
  vim.fn.writefile(content, M.file())
end

---@return string[]? lines nil when nothing ran yet
function M.read()
  if vim.fn.filereadable(M.file()) == 0 then return nil end
  return vim.fn.readfile(M.file())
end

return M
