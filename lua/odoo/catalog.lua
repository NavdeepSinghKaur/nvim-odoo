-- The `odoo-nvim` commands an AI agent may run: ONE list that the agent brief (the table an agent
-- reads in AGENTS.md), `odoo-nvim commands --json` (for harnesses that want to discover them) and
-- the tests that keep scripts/cli.lua honest are all made from. Before this, the same table was
-- typed by hand in five files and the copies drifted. Plugin-free: `odoo-nvim` runs it.
local M = {}

---@class OdooCatalogCommand
---@field name string the word after `odoo-nvim`
---@field usage string how to call it (what an agent types)
---@field task string what it is for, in the words of the person who wants it done
---@field docker boolean needs the Odoo container (false: works with files only)
---@field effect "read"|"database"|"container" what it changes: nothing, the database, or the running server
---@field json boolean accepts --json

--- Commands an agent should know. `setup`, `help` and `brief` are for people: see HUMAN_ONLY.
---@type OdooCatalogCommand[]
M.commands = {
  {
    name = "update",
    usage = "odoo-nvim update <module> [--no-restart]",
    task = "Apply a change to a module (Python, XML, data, fields)",
    docker = true,
    effect = "database",
    json = true,
  },
  {
    name = "install",
    usage = "odoo-nvim install <module>",
    task = "Install a module",
    docker = true,
    effect = "database",
    json = true,
  },
  {
    name = "test",
    usage = "odoo-nvim test <module>  |  odoo-nvim test /<module>:<Class>.<method>",
    task = "Run the tests of a module, or one test class or method",
    docker = true,
    effect = "database",
    json = true,
  },
  {
    name = "frontend",
    usage = "odoo-nvim frontend [<module>]",
    task = "After writing JS, XML templates or SCSS: is every file loaded by a bundle, does every template exist",
    docker = false,
    effect = "read",
    json = true,
  },
  {
    name = "logs",
    usage = "odoo-nvim logs [--tail N]",
    task = "Read the server log",
    docker = true,
    effect = "read",
    json = false,
  },
  {
    name = "last",
    usage = "odoo-nvim last",
    task = "Output of the last update / install / test again",
    docker = false,
    effect = "read",
    json = false,
  },
  {
    name = "dbs",
    usage = "odoo-nvim dbs",
    task = "List the databases (any command takes `--db <name>` to use another one)",
    docker = true,
    effect = "read",
    json = false,
  },
  {
    name = "start",
    usage = "odoo-nvim start  |  odoo-nvim stop  |  odoo-nvim restart",
    task = "Start, stop or restart the Odoo server",
    docker = true,
    effect = "container",
    json = false,
  },
  {
    name = "info",
    usage = "odoo-nvim info  |  odoo-nvim doctor",
    task = "What is configured / is everything in place",
    docker = false,
    effect = "read",
    json = true,
  },
}

--- Commands of scripts/cli.lua that are deliberately not in the catalog, and why.
---@type table<string, string>
M.not_listed = {
  stop = "listed with start",
  restart = "listed with start",
  doctor = "listed with info",
  setup = "writes the user's settings: a person decides, not an agent",
  brief = "writes the AGENTS.md block this catalog feeds",
  commands = "this catalog, printed",
  help = "the usage text",
}

--- The catalog as a markdown table (the brief puts it in the project's AGENTS.md).
---@return string[] lines
function M.table()
  local effects = { read = "no", database = "database", container = "server" }
  local lines = {
    "| Task | Command | Docker | Changes |",
    "|---|---|---|---|",
  }
  for _, command in ipairs(M.commands) do
    local usage = "`" .. command.usage:gsub("  |  ", "` or `") .. "`"
    table.insert(
      lines,
      ("| %s | %s | %s | %s |"):format(command.task, usage, command.docker and "yes" or "no", effects[command.effect])
    )
  end
  return lines
end

--- The catalog as JSON: what `odoo-nvim commands --json` prints.
---@return string
function M.json() return vim.json.encode({ commands = M.commands }) end

return M
