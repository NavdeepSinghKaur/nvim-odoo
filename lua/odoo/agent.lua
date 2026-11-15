-- A brief for AI coding agents (Claude Code, Codex, Cursor...) working in your addons repo:
-- how to update and test modules with `odoo-nvim`, and which folders are yours.
-- :Odoo ai-init writes it into the AGENTS.md (or CLAUDE.md) of the workspace, between two
-- marker lines, so running it again replaces the block and leaves the rest of the file alone.
local settings = require("odoo.settings")
local paths = require("odoo.paths")
local compose = require("odoo.compose")
local M = {}

local BLOCK_START = "<!-- odoo-nvim:start (written by :Odoo ai-init; run it again to update) -->"
local BLOCK_START_PATTERN = "^<!%-%- odoo%-nvim:start"
local BLOCK_END = "<!-- odoo-nvim:end -->"

--- Folders as text: relative to the workspace where possible, in backticks.
---@param dirs string[]
---@return string
local function folder_list(dirs)
  local names = {}
  for _, dir in ipairs(dirs) do
    local inside = dir:sub(1, #settings.workspace + 1) == settings.workspace .. "/"
    table.insert(names, "`" .. (inside and dir:sub(#settings.workspace + 2) or dir) .. "/`")
  end
  return table.concat(names, ", ")
end

--- The brief for this project (templates/agent-brief.md with the settings filled in).
---@return string[] lines
function M.brief()
  local values = {
    version = paths.odoo_version() or "",
    own_addons = folder_list(settings.own_addons),
    readonly_paths = folder_list(settings.readonly_paths),
    core = "`" .. settings.core .. "/`",
    database = compose.db(),
    web_url = settings.web_url,
  }
  local lines = vim.fn.readfile(settings.config_dir .. "/templates/agent-brief.md")
  return vim.tbl_map(function(line) return (line:gsub("{{([%w_]+)}}", values)) end, lines)
end

--- The agent instructions file of the workspace: an existing AGENTS.md or CLAUDE.md, else a new AGENTS.md.
---@return string
function M.target()
  for _, name in ipairs({ "AGENTS.md", "CLAUDE.md" }) do
    local file = settings.workspace .. "/" .. name
    if vim.fn.filereadable(file) == 1 then return file end
  end
  return settings.workspace .. "/AGENTS.md"
end

--- `content` with the brief block replaced, or appended when there is none yet.
---@param content string[]
---@param block string[]
---@return string[] lines, boolean replaced
function M.merge(content, block)
  local first, last
  for i, line in ipairs(content) do
    if not first and line:match(BLOCK_START_PATTERN) then first = i end
    if first and line == BLOCK_END then
      last = i
      break
    end
  end
  local merged = {}
  if first and last then
    vim.list_extend(merged, content, 1, first - 1)
    vim.list_extend(merged, block)
    vim.list_extend(merged, content, last + 1)
    return merged, true
  end
  vim.list_extend(merged, content)
  if #merged > 0 and merged[#merged] ~= "" then table.insert(merged, "") end
  return vim.list_extend(merged, block), false
end

--- Write the brief into the workspace.
---@param file? string default: target()
---@return string file, "created"|"updated"|"added" what happened
function M.write(file)
  file = file or M.target()
  local block = { BLOCK_START }
  vim.list_extend(block, M.brief())
  table.insert(block, BLOCK_END)
  local exists = vim.fn.filereadable(file) == 1
  local merged, replaced = M.merge(exists and vim.fn.readfile(file) or {}, block)
  vim.fn.writefile(merged, file)
  return file, not exists and "created" or replaced and "updated" or "added"
end

return M
