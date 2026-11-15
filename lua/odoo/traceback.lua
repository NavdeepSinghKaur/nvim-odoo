-- Reading Odoo output: find "file:line" references and turn tracebacks into quickfix items.
-- Container paths are translated to local paths (lua/odoo/paths.lua).
local paths = require("odoo.paths")
local M = {}

--- Find a "file:line" reference in a log line.
---@param line string
---@return string? local_path, integer? lnum nil when there is none or the file is not readable
function M.parse_location(line)
  local file, lnum = line:match('File "([^"]+)", line (%d+)')
  if not file then
    file, lnum = line:match("while parsing ([^%s:]+%.xml):(%d+)")
  end
  if not file then
    file, lnum = line:match("(/[%w_%-%./]+%.%a+):(%d+)")
  end
  if not file then
    file = line:match("(/mnt/[%w_%-%./]+%.%a+)")
      or line:match("(/usr/lib/python3/dist%-packages/odoo/[%w_%-%./]+%.%a+)")
    lnum = 1
  end
  if not file then return nil end
  local local_file = paths.to_local(file)
  if vim.fn.filereadable(local_file) == 1 then return local_file, tonumber(lnum) end
  return nil
end

--- Quickfix items from log lines: every readable traceback frame, plus the error lines.
--- Your own code comes first: that is usually where the bug is.
---@param lines string[]
---@return table[] items for vim.fn.setqflist
function M.to_qf(lines)
  local own, others = {}, {}
  for i, line in ipairs(lines) do
    local file, lnum = M.parse_location(line)
    if file then
      local next_line = lines[i + 1] and vim.trim(lines[i + 1]) or ""
      local text = vim.trim(line:gsub("^.-line %d+,?%s*", "")) .. "  │ " .. next_line
      table.insert(paths.is_own(file) and own or others, { filename = file, lnum = lnum, text = text })
    elseif line:match(" ERROR ") or line:match(" CRITICAL ") or line:match("^FAIL:") or line:match("^ERROR:") then
      table.insert(others, { text = line })
    end
  end
  return vim.list_extend(own, others)
end

--- Rewrite the container paths in a line to local paths, so the line can be read (and its
--- files opened) outside the container.
---@param line string
---@return string
function M.localize(line)
  for _, mapping in ipairs(paths.mappings()) do
    if line:find(mapping.remote, 1, true) then
      local pattern = vim.pesc(mapping.remote) .. "([/\"':%s])"
      line = line:gsub(pattern, function(after) return mapping["local"] .. after end)
    end
  end
  return line
end

return M
