-- A brief for AI coding agents (Claude Code, Codex, Cursor...) working in your addons repo:
-- how to update and test modules with `odoo-nvim`, and which folders are yours.
-- :Odoo ai-init writes it into the AGENTS.md (or CLAUDE.md) of the workspace, between two
-- marker lines, so running it again replaces the block and leaves the rest of the file alone.
local settings = require("odoo.settings")
local paths = require("odoo.paths")
local compose = require("odoo.compose")
local catalog = require("odoo.catalog")
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
  local filled = {}
  for _, line in ipairs(lines) do
    if line == "{{commands}}" then
      vim.list_extend(filled, catalog.table()) -- many lines: the one list of odoo-nvim commands
    else
      table.insert(filled, (line:gsub("{{([%w_]+)}}", values)))
    end
  end
  return filled
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

--- Does the workspace tell agents about odoo-nvim, and is what it says current? An agent only knows
--- the commands that are in its project file, so a missing or old block means it guesses `docker`.
---@return "missing"|"stale"|"unreachable"|"current" state, string file
function M.status()
  local file = M.target()
  local block = { BLOCK_START }
  vim.list_extend(block, M.brief())
  table.insert(block, BLOCK_END)
  local content = vim.fn.filereadable(file) == 1 and vim.fn.readfile(file) or {}
  local merged, replaced = M.merge(content, block)
  if not replaced then return "missing", file end
  if not vim.deep_equal(merged, content) then return "stale", file end
  -- Claude Code reads CLAUDE.md, not AGENTS.md: a CLAUDE.md that does not import it hides the block
  local claude = settings.workspace .. "/CLAUDE.md"
  if file ~= claude and vim.fn.filereadable(claude) == 1 then
    local text = table.concat(vim.fn.readfile(claude), "\n")
    if not text:find("@AGENTS.md", 1, true) then return "unreachable", claude end
  end
  return "current", file
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
  -- Claude Code does not read AGENTS.md: a CLAUDE.md that imports it makes both kinds of agent see the block
  local claude = settings.workspace .. "/CLAUDE.md"
  if not exists and vim.fs.basename(file) == "AGENTS.md" and vim.fn.filereadable(claude) == 0 then
    vim.fn.writefile({ "@AGENTS.md" }, claude)
  end
  return file, not exists and "created" or replaced and "updated" or "added"
end

return M
