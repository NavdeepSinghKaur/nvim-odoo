-- The :Odoo command and the <Space>o keys, declared once: each entry is a sub-command with
-- its description and, when it has one, its key. `:Odoo` alone lists them all.
local paths = require("odoo.paths")
local M = {}

local function odoo() return require("odoo") end
local function docker() return require("odoo.docker") end
local function pickers() return require("odoo.pickers") end

--- Run fn(module) with the module of the current file, or ask which one.
---@param fn fun(module: string)
---@param title? string
local function with_module(fn, title)
  local name = paths.module_of()
  if name then return fn(name) end
  pickers().pick_module(title or "Which module?", fn)
end

--- An action on a module: the one given, else the module of the current file, else ask.
---@param fn fun(module: string)
---@return fun(module?: string)
local function on_module(fn)
  return function(module)
    if module then return fn(module) end
    with_module(fn)
  end
end

---@class OdooCommand
---@field name string sub-command: `:Odoo <name>`
---@field run fun(arg?: string)
---@field desc string shown in the `:Odoo` menu
---@field key? string key after <leader>o
---@field key_desc? string shorter text for the <Space>o menu (default: desc)

---@type OdooCommand[]
M.list = {
  -- server
  {
    name = "update",
    key = "u",
    key_desc = "Update module + restart",
    desc = "Update module (-u) + restart (Python & XML changes)",
    run = on_module(function(module) docker().update(module, true) end),
  },
  {
    name = "update-xml",
    key = "U",
    key_desc = "Update module (XML only, no restart)",
    desc = "Update module without restart (XML/data only, faster)",
    run = on_module(function(module) docker().update(module, false) end),
  },
  {
    name = "install",
    key = "i",
    key_desc = "Install module…",
    desc = "Install a module",
    run = function(module)
      if module then return docker().install(module) end
      pickers().pick_module("Install which module?", docker().install)
    end,
  },
  { name = "restart", key = "r", desc = "Restart the Odoo server", run = function() docker().restart() end },
  {
    name = "start",
    key = "S",
    key_desc = "Start Odoo (normal mode)",
    desc = "Start Odoo in NORMAL mode (leaves debug mode)",
    run = function() docker().up() end,
  },
  {
    name = "stop",
    key = "K",
    key_desc = "Stop (kill) Odoo",
    desc = "Stop the Odoo container",
    run = function() docker().stop() end,
  },
  { name = "logs", key = "l", desc = "Follow the Odoo log", run = function() docker().logs() end },
  {
    name = "qf",
    key = "q",
    key_desc = "Log tracebacks → quickfix",
    desc = "Tracebacks of the log panel → quickfix",
    run = function() require("odoo.log").qf_from_current() end,
  },
  -- tests
  {
    name = "test",
    key = "t",
    key_desc = "Test current module",
    desc = "Run the tests of the module",
    run = on_module(function(module) docker().test(module) end),
  },
  {
    name = "test-cursor",
    key = "T",
    key_desc = "Test under cursor",
    desc = "Run the test class/method under the cursor",
    run = function() odoo().test_at_cursor() end,
  },
  -- debug
  {
    name = "debug",
    key = "d",
    key_desc = "Debug Odoo (debugpy)",
    desc = "Start debug mode (debugpy) + attach the debugger",
    run = function() odoo().debug() end,
  },
  { name = "attach", desc = "Attach debugger (Odoo already in debug mode)", run = function() odoo().attach() end },
  -- consoles
  {
    name = "shell",
    key = "s",
    key_desc = "Odoo shell",
    desc = "Odoo shell (python with env) on the DB",
    run = function() docker().shell() end,
  },
  { name = "psql", key = "p", key_desc = "psql", desc = "psql on the DB", run = function() docker().psql() end },
  {
    name = "bash",
    key = "b",
    key_desc = "Container bash",
    desc = "bash inside the Odoo container",
    run = function() docker().bash() end,
  },
  {
    name = "db",
    key = "D",
    key_desc = "Choose database",
    desc = "Choose the database for these commands",
    run = function() docker().pick_db() end,
  },
  -- navigation
  {
    name = "models",
    key = "m",
    key_desc = "Find model",
    desc = "Find a model (definition + every _inherit)",
    run = function() pickers().models() end,
  },
  {
    name = "model-cursor",
    key = "M",
    desc = "Find model under cursor",
    run = function() pickers().model_at_cursor() end,
  },
  {
    name = "xmlids",
    key = "x",
    key_desc = "Find XML id",
    desc = "Find an XML id",
    run = function() pickers().xmlids() end,
  },
  {
    name = "xmlid-cursor",
    key = "X",
    desc = "Find XML id under cursor",
    run = function() pickers().xmlid_at_cursor() end,
  },
  {
    name = "views",
    key = "v",
    key_desc = "Views/actions of this model",
    desc = "Views/actions/rules of a model",
    run = function(model) pickers().views(model) end,
  },
  {
    name = "modules",
    key = "o",
    key_desc = "Find module",
    desc = "Find a module",
    run = function() pickers().modules() end,
  },
  {
    name = "manifest",
    key = ".",
    key_desc = "Open manifest",
    desc = "Open __manifest__.py of current module",
    run = function() odoo().open_manifest() end,
  },
  { name = "files", key = "f", desc = "Files in this module", run = function() pickers().files_module() end },
  { name = "grep", key = "g", desc = "Grep in this module", run = function() pickers().grep_module() end },
  { name = "files-core", key = "c", desc = "Files in Odoo core", run = function() pickers().files_core() end },
  { name = "grep-core", key = "C", desc = "Grep in Odoo core", run = function() pickers().grep_core() end },
  { name = "grep-addons", key = "a", desc = "Grep in ALL addons", run = function() pickers().grep_addons() end },
  { name = "files-addons", key = "A", desc = "Files in ALL addons", run = function() pickers().files_addons() end },
  {
    name = "grep-word",
    key = "w",
    desc = "Word under cursor in ALL addons",
    run = function() pickers().grep_word_addons() end,
  },
  {
    name = "browser",
    key = "B",
    key_desc = "Open in browser (debug=1)",
    desc = "Open Odoo in the browser (?debug=1)",
    run = function() odoo().browser(true) end,
  },
  -- setup
  {
    name = "info",
    key = "?",
    key_desc = "Odoo status",
    desc = "Container / DB / module status",
    run = function() odoo().info() end,
  },
  {
    name = "sync-core",
    desc = "Re-copy Odoo core source from the Docker image",
    run = function() odoo().sync_core() end,
  },
  {
    name = "config",
    desc = "Edit YOUR settings: paths, docker service, db (lua/odoo/local.lua)",
    run = function() odoo().config() end,
  },
}

--- Add a sub-command (used by optional parts of the config).
---@param command OdooCommand
function M.add(command) table.insert(M.list, command) end

---@param name string
---@return OdooCommand?
function M.get(name)
  for _, command in ipairs(M.list) do
    if command.name == name then return command end
  end
end

---@return string[] sorted sub-command names
local function names()
  local result = vim.tbl_map(function(command) return command.name end, M.list)
  table.sort(result)
  return result
end

--- `:Odoo` without arguments: choose from every sub-command.
local function menu()
  vim.ui.select(names(), {
    prompt = "Odoo",
    format_item = function(name) return ("%-13s %s"):format(name, M.get(name).desc) end,
  }, function(choice)
    if choice then M.get(choice).run() end
  end)
end

--- Completion: sub-command names, then module names (update / install / test take one).
local function complete(lead, line)
  local function starts_with_lead(name) return name:find(lead, 1, true) == 1 end
  if #vim.split(line, "%s+") <= 2 then return vim.tbl_filter(starts_with_lead, names()) end
  local modules = {}
  for _, dir in ipairs(paths.addon_dirs()) do
    for name, kind in vim.fs.dir(dir) do
      if kind == "directory" and starts_with_lead(name) then table.insert(modules, name) end
    end
  end
  return modules
end

function M.setup()
  vim.api.nvim_create_user_command("Odoo", function(opts)
    local name, arg = opts.fargs[1], opts.fargs[2]
    if not name then return menu() end
    local command = M.get(name)
    if not command then return vim.notify("Unknown :Odoo " .. name, vim.log.levels.ERROR) end
    command.run(arg)
  end, { nargs = "*", desc = "Odoo helpers", complete = complete })

  local function map(key, rhs, desc) vim.keymap.set("n", "<leader>o" .. key, rhs, { desc = desc, silent = true }) end
  for _, command in ipairs(M.list) do
    -- keys run the command without an argument: it works on the current file / asks
    if command.key then map(command.key, function() command.run() end, command.key_desc or command.desc) end
  end
  map("O", "<Cmd>Odoo<CR>", "All Odoo commands…")
end

return M
