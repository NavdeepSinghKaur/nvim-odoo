local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- A project whose compose command is known without docker.
local function agent_for_project()
  local settings, root = H.project({ db = "projectdb" })
  H.write(root .. "/core/odoo/release.py", { "version_info = (18, 0, 0, FINAL, 0, '')" })
  return require("odoo.agent"), settings, root
end

T["the brief names the project's folders, version and database"] = function()
  local agent, _, root = agent_for_project()
  local text = table.concat(agent.brief(), "\n")
  local function has(part) eq({ part, text:find(part, 1, true) ~= nil }, { part, true }) end
  has("This project runs Odoo 18.0 in Docker")
  has("Write code only here: `custom/`")
  has("`" .. root .. "/core/`, `oca/`")
  has("Database: `projectdb`")
  eq(text:find("{{", 1, true), nil) -- every placeholder is filled
end

T["writes a new AGENTS.md, then updates only its own block"] = function()
  local agent, settings = agent_for_project()
  local file, action = agent.write()
  eq({ file, action }, { settings.workspace .. "/AGENTS.md", "created" })

  local lines = vim.fn.readfile(file)
  table.insert(lines, 1, "# Project notes")
  table.insert(lines, "Text after the block stays.")
  vim.fn.writefile(lines, file)
  eq(select(2, agent.write()), "updated")
  local updated = vim.fn.readfile(file)
  eq(updated, lines) -- same brief, same surrounding text, no second block
end

T["adds the block to an existing CLAUDE.md"] = function()
  local agent, settings = agent_for_project()
  H.write(settings.workspace .. "/CLAUDE.md", { "# House rules" })
  local file, action = agent.write()
  eq({ file, action }, { settings.workspace .. "/CLAUDE.md", "added" })
  local lines = vim.fn.readfile(file)
  eq({ lines[1], lines[2] }, { "# House rules", "" })
  eq(lines[#lines], "<!-- odoo-nvim:end -->")
end

T["a new AGENTS.md gets a CLAUDE.md that imports it (Claude Code reads CLAUDE.md)"] = function()
  local agent, settings = agent_for_project()
  agent.write()
  eq(vim.fn.readfile(settings.workspace .. "/CLAUDE.md"), { "@AGENTS.md" })
end

T["the brief has every catalog command"] = function()
  local agent = agent_for_project()
  local text = table.concat(agent.brief(), "\n")
  for _, command in ipairs(require("odoo.catalog").commands) do
    eq(
      { command.name, text:find("`" .. command.usage:match("^[^|]+"):gsub("%s+$", ""), 1, true) ~= nil },
      { command.name, true }
    )
  end
end

T["status: missing, current, stale, and a CLAUDE.md that hides the block"] = function()
  local agent, settings = agent_for_project()
  eq((agent.status()), "missing")
  agent.write()
  eq((agent.status()), "current")
  local file = settings.workspace .. "/AGENTS.md"
  local lines = vim.fn.readfile(file)
  for i, line in ipairs(lines) do
    if line:find("odoo-nvim update", 1, true) then lines[i] = "| old row |" end
  end
  vim.fn.writefile(lines, file)
  eq((agent.status()), "stale")
  agent.write()
  vim.fn.writefile({ "# no import here" }, settings.workspace .. "/CLAUDE.md")
  local state, shown = agent.status()
  eq({ state, shown }, { "unreachable", settings.workspace .. "/CLAUDE.md" })
end

return T
