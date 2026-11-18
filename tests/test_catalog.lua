local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local catalog = require("odoo.catalog")

--- Names of every `commands.<name>` that scripts/cli.lua defines, and its usage text.
local function cli_source()
  local text = table.concat(vim.fn.readfile("scripts/cli.lua"), "\n")
  local names = {}
  for name in text:gmatch("\nfunction commands%.(%w+)%(") do
    names[name] = true
  end
  for name in text:gmatch("\ncommands%.(%w+) = ") do
    names[name] = true
  end
  return names, text:match("local USAGE = %[%[(.-)%]%]")
end

T["every command of the CLI is in the catalog or says why it is not"] = function()
  local names = cli_source()
  local listed = {}
  for _, command in ipairs(catalog.commands) do
    listed[command.name] = true
  end
  local missing = {}
  for name in pairs(names) do
    if not listed[name] and not catalog.not_listed[name] then table.insert(missing, name) end
  end
  table.sort(missing)
  eq(missing, {}) -- a new CLI command: add it to lua/odoo/catalog.lua, so agents learn about it
end

T["every command of the catalog exists and is in the usage text"] = function()
  local names, usage = cli_source()
  for _, command in ipairs(catalog.commands) do
    eq({ command.name, names[command.name] }, { command.name, true })
    eq({ command.name, usage:find("\n  " .. command.name, 1, true) ~= nil }, { command.name, true })
    eq({ command.name, vim.startswith(command.usage, "odoo-nvim " .. command.name) }, { command.name, true })
  end
  for name in pairs(catalog.not_listed) do
    eq({ name, names[name] }, { name, true }) -- no stale excuse for a command that is gone
  end
end

T["the table has one row per command"] = function()
  local lines = catalog.table()
  eq(#lines, #catalog.commands + 2)
  for _, line in ipairs(lines) do
    eq({ line, select(2, line:gsub("|", "")) }, { line, 5 }) -- a "|" inside a cell would break the table
  end
  eq(lines[1], "| Task | Command | Docker | Changes |")
  eq(
    lines[3],
    "| Apply a change to a module (Python, XML, data, fields) | `odoo-nvim update <module> [--no-restart]` | yes | database |"
  )
  eq(lines[5]:find("`odoo-nvim test <module>` or `odoo-nvim test /<module>:<Class>.<method>`", 1, true) ~= nil, true)
end

T["the JSON lists the same commands"] = function()
  local decoded = vim.json.decode(catalog.json())
  eq(#decoded.commands, #catalog.commands)
  eq(decoded.commands[1].name, "update")
  eq(decoded.commands[1].docker, true)
end

T["the CLI prints the catalog as a table and as JSON"] = function()
  H.project()
  local table_out = vim.system({ "scripts/odoo-nvim", "commands" }, { text = true }):wait()
  eq(table_out.code, 0)
  eq(table_out.stdout:find("| Task | Command |", 1, true) ~= nil, true)
  local json_out = vim.system({ "scripts/odoo-nvim", "commands", "--json" }, { text = true }):wait()
  eq(#vim.json.decode(json_out.stdout).commands, #catalog.commands)
end

return T
