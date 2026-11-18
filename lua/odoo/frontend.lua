-- Static check of the front-end files of an addon (Odoo 18: OWL, assets bundles, SCSS), without
-- Docker or a browser: is every file under static/src loaded by a bundle, does every manifest
-- entry exist, does every `static template` of a component have its `t-name`? It exists so an AI
-- agent that writes JS gets feedback in a second. Plugin-free: `odoo-nvim frontend` runs it.
local settings = require("odoo.settings")
local M = {}

---@class OdooFrontendProblem
---@field severity "error"|"warn"
---@field file string
---@field line integer
---@field text string
---@field module? string set by the command line tool

local EXTENSIONS = { js = true, scss = true, css = true, xml = true }

---@param path string
---@return string[]
local function lines_of(path) return vim.fn.readfile(path) end

--- Files under `dir` (relative paths), at any depth.
---@param dir string
---@return string[]
local function files_under(dir)
  local files = {}
  if vim.fn.isdirectory(dir) == 0 then return files end
  for name, kind in vim.fs.dir(dir, { depth = 12 }) do
    if kind == "file" then table.insert(files, name) end
  end
  return files
end

--- The text of the `"assets": { ... }` value of a manifest ("" when it has none).
---@param manifest string[] lines
---@return string
local function assets_block(manifest)
  local text =
    table.concat(vim.tbl_map(function(line) return (line:gsub("%s#.*$", ""):gsub("^%s*#.*$", "")) end, manifest), "\n")
  local _, key_end = text:find("[\"']assets[\"']%s*:%s*")
  if not key_end then return "" end
  local start = text:find("{", key_end, true)
  if not start or start ~= key_end + 1 then return "" end
  local depth = 0
  for i = start, #text do
    local c = text:sub(i, i)
    if c == "{" then depth = depth + 1 end
    if c == "}" then
      depth = depth - 1
      if depth == 0 then return text:sub(start, i) end
    end
  end
  return ""
end

---@class OdooAssetEntry
---@field path string relative to the addons folder: `module/static/src/...`
---@field removed boolean from a ("remove", ...) directive

--- Every file path a manifest puts in a bundle.
---@param manifest string[] lines
---@return OdooAssetEntry[]
function M.asset_entries(manifest)
  -- black splits long paths into two literals: "a/" "b" is one string
  local block = assets_block(manifest):gsub("([\"'])%s*\n%s*[\"']", "")
  local entries = {}
  ---@param path string
  ---@param removed boolean
  local function add(path, removed)
    path = path:gsub("^/", "")
    if path:find("/", 1, true) then table.insert(entries, { path = path, removed = removed }) end
  end
  -- ("remove", path) and ("after", target, new_file): the file that is loaded is the last string
  local plain = block:gsub("%(([^()]*)%)", function(tuple)
    local strings = {}
    for text in tuple:gmatch("[\"']([^\"']+)[\"']") do
      table.insert(strings, text)
    end
    local directive = table.remove(strings, 1)
    if directive and #strings > 0 then add(strings[#strings], directive == "remove") end
    return ""
  end)
  for path in plain:gmatch("[\"']([^\"']+)[\"']") do
    add(path, false)
  end
  return entries
end

--- Check one addon.
---@param dir string folder of the addon (holds __manifest__.py)
---@return OdooFrontendProblem[]
function M.check(dir)
  local module = vim.fs.basename(dir)
  local manifest_file = dir .. "/__manifest__.py"
  local problems = {}
  ---@param severity "error"|"warn"
  ---@param file string
  ---@param line integer
  ---@param text string
  local function add(severity, file, line, text)
    table.insert(problems, { severity = severity, file = file, line = line, text = text })
  end
  if vim.fn.filereadable(manifest_file) == 0 then
    add("error", dir, 1, "no __manifest__.py")
    return problems
  end

  -- files that exist
  local src = {}
  for _, name in ipairs(files_under(dir .. "/static/src")) do
    local ext = name:match("%.(%w+)$")
    if EXTENSIONS[ext] and not name:find("^lib/") and not name:find("/lib/", 1, true) then
      table.insert(src, "static/src/" .. name)
    end
  end

  -- what the manifest loads
  local loaded = {}
  local entries = M.asset_entries(lines_of(manifest_file))
  local prefix = module .. "/"
  local all = files_under(dir .. "/static")
  for _, entry in ipairs(entries) do
    if vim.startswith(entry.path, prefix) and not entry.removed then
      local relative = entry.path:sub(#prefix + 1)
      if relative:find("*", 1, true) then
        local match = vim.glob.to_lpeg(relative)
        local count = 0
        for _, name in ipairs(all) do
          if match:match("static/" .. name) then
            loaded["static/" .. name] = true
            count = count + 1
          end
        end
        if count == 0 then add("warn", manifest_file, 1, "the pattern '" .. entry.path .. "' matches no file") end
      elseif vim.fn.filereadable(dir .. "/" .. relative) == 1 then
        loaded[relative] = true
      else
        add("error", manifest_file, 1, "the bundle lists '" .. entry.path .. "' but the file does not exist")
      end
    end
  end

  -- files that a data / report XML names itself (<link href="/module/static/...">, ir.asset) are not orphans
  local xml_parts = {}
  for _, name in ipairs(files_under(dir)) do
    if name:match("%.xml$") and not name:find("^static/") then
      table.insert(xml_parts, table.concat(lines_of(dir .. "/" .. name), "\n"))
    end
  end
  local xml_text = table.concat(xml_parts, "\n")
  for _, relative in ipairs(src) do
    if not loaded[relative] and not xml_text:find("/" .. module .. "/" .. relative, 1, true) then
      add("error", dir .. "/" .. relative, 1, "no bundle in __manifest__.py loads this file (add it under 'assets')")
    end
  end

  -- templates: `static template = "module.Name"` needs a t-name
  local defined = {}
  for _, relative in ipairs(src) do
    if relative:match("%.xml$") then
      for _, line in ipairs(lines_of(dir .. "/" .. relative)) do
        for name in line:gmatch("t%-name=[\"']([^\"']+)[\"']") do
          defined[name] = true
        end
      end
    end
  end
  for _, relative in ipairs(src) do
    if relative:match("%.js$") then
      local file = dir .. "/" .. relative
      for number, line in ipairs(lines_of(file)) do
        local template = line:match("static%s+template%s*=%s*[\"']([^\"']+)[\"']")
        if template and vim.startswith(template, module .. ".") and not defined[template] then
          add("error", file, number, "template '" .. template .. "' has no t-name in this module's XML files")
        end
        if line:find("odoo.define(", 1, true) then
          add("warn", file, number, "legacy odoo.define module: use ES modules (import / export)")
        end
        if line:match("require%([\"']web%.") then
          add("warn", file, number, "legacy require('web.…'): import from '@web/…' instead")
        end
      end
    end
  end

  table.sort(problems, function(a, b)
    if a.severity ~= b.severity then return a.severity == "error" end
    if a.file ~= b.file then return a.file < b.file end
    return a.line < b.line
  end)
  return problems
end

--- Addons of the user's own folders (the ones agents are allowed to write).
---@return table<string, string> name -> folder
function M.own_modules()
  local modules = {}
  local function scan(dir, depth)
    for name, kind in vim.fs.dir(dir) do
      local sub = dir .. "/" .. name
      if kind == "directory" and not name:match("^%.") then
        if vim.fn.filereadable(sub .. "/__manifest__.py") == 1 then
          modules[name] = sub
        elseif depth > 0 then
          scan(sub, depth - 1)
        end
      end
    end
  end
  for _, dir in ipairs(settings.own_addons) do
    scan(dir, 2)
  end
  return modules
end

return M
