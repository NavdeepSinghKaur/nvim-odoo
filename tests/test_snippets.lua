local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- The snippets of one VSCode-format file, decoded.
---@param name string python.json, xml.json...
---@return table<string, table>
local function snippets_of(name)
  local text = table.concat(vim.fn.readfile("snippets/" .. name), "\n")
  return vim.json.decode(text)
end

T["the Odoo python and XML snippets parse and every entry has a prefix, a description and a body"] = function()
  for _, name in ipairs({ "python.json", "xml.json" }) do
    for title, snippet in pairs(snippets_of(name)) do
      local where = name .. ": " .. title
      assert(type(snippet.prefix) == "string", where .. " has no prefix")
      assert(type(snippet.description) == "string", where .. " has no description")
      assert(vim.islist(snippet.body) and #snippet.body > 0, where .. " has no body")
    end
  end
end

T["the prefixes of an Odoo file are unique and start with o (type o + a few letters)"] = function()
  for _, name in ipairs({ "python.json", "xml.json" }) do
    local seen = {}
    for title, snippet in pairs(snippets_of(name)) do
      local where = name .. ": " .. title
      assert(not seen[snippet.prefix], where .. " repeats the prefix " .. snippet.prefix)
      seen[snippet.prefix] = true
      assert(vim.startswith(snippet.prefix, "o"), where .. " does not start with o")
    end
  end
end

T["every prefix of the Odoo snippets is listed in the cheatsheet"] = function()
  local cheatsheet = table.concat(vim.fn.readfile("CHEATSHEET.md"), "\n")
  local missing = {}
  for _, name in ipairs({ "python.json", "xml.json" }) do
    for _, snippet in pairs(snippets_of(name)) do
      if not cheatsheet:find("`" .. snippet.prefix .. "`", 1, true) then table.insert(missing, snippet.prefix) end
    end
  end
  table.sort(missing)
  eq(missing, {})
end

return T
