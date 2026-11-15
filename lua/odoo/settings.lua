-- ============================================================================
--  Odoo project settings = the defaults below + YOUR values from lua/odoo/local.lua
--
--  Don't edit this file: run  :Odoo setup  (detects most of it) or  :Odoo config  (opens
--  lua/odoo/local.lua, which is git-ignored). See lua/odoo/local.example.lua for every option.
--
--  The module is the settings table itself: require("odoo.settings").workspace
--  It fills itself the first time a value is read. Tests and the command line tool call
--  load(values) to use their own values instead of local.lua.
-- ============================================================================

---@class OdooPathMapping
---@field remote string path inside the container
---@field local string path on this machine

---@class OdooDebugSettings
---@field host string
---@field port integer
---@field extra_args string[] extra odoo args only in debug mode, e.g. { "--dev=xml" }

---@class OdooSettings
---@field local_file string lua/odoo/local.lua (or $ODOO_NVIM_SETTINGS)
---@field example_file string lua/odoo/local.example.lua
---@field config_dir string this Neovim config (the folder with init.lua)
---@field configured boolean local.lua exists (or values were given to load)
---@field problems string[] what is wrong with the user's values (empty = fine)
---@field workspace string
---@field own_addons string[]
---@field core string
---@field core_addons string
---@field addons_paths string[]
---@field readonly_paths string[]
---@field python string
---@field compose_dir string
---@field service string
---@field db_service string
---@field container? string
---@field odoo_conf string
---@field odoo_bin string
---@field db_user string
---@field core_remote string
---@field core_image? string
---@field db? string
---@field oneoff_args string[]
---@field debug OdooDebugSettings
---@field path_mappings? OdooPathMapping[]
---@field web_url string
---@field odools_config? string
---@field odoo_ls_cmd string
local M = {}

-- Next to this file, wherever the config is checked out (also right for the command line
-- tool, which runs without the Neovim config).
local module_dir = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2)))
M.local_file = vim.env.ODOO_NVIM_SETTINGS or (module_dir .. "/local.lua") -- the variable: another project
M.example_file = module_dir .. "/local.example.lua"
M.config_dir = vim.fs.dirname(vim.fs.dirname(module_dir)) -- the folder with init.lua and scripts/

-- Every key local.lua may set, with its Lua type.
local KEY_TYPES = {
  workspace = "string",
  own_addons = "table",
  core = "string",
  core_addons = "string",
  addons_paths = "table",
  readonly_paths = "table",
  python = "string",
  compose_dir = "string",
  service = "string",
  db_service = "string",
  container = "string",
  odoo_conf = "string",
  odoo_bin = "string",
  db_user = "string",
  core_remote = "string",
  core_image = "string",
  db = "string",
  oneoff_args = "table",
  debug = "table",
  path_mappings = "table",
  web_url = "string",
  odools_config = "string",
  odoo_ls_cmd = "string",
}

---@param path string
---@return string absolute path with ~ and $VARS expanded
local function expand(path) return vim.fs.normalize(vim.fn.expand(path)) end

---@param list? string[]
---@return string[]
local function expand_list(list) return vim.tbl_map(expand, list or {}) end

--- Read local.lua.
---@return table values, string? problem
local function read_local_file()
  local ok, result = pcall(dofile, M.local_file)
  if ok and type(result) == "table" then return result end
  local reason = ok and "it must return a table" or tostring(result)
  return {}, "lua/odoo/local.lua has an error (using defaults): " .. reason
end

--- Unknown keys and values of the wrong type. The bad values are removed from `user`,
--- so the defaults apply instead of failing later in some unrelated place.
---@param user table
---@return string[] problems
local function check_keys(user)
  local problems = {}
  local keys = vim.tbl_keys(user)
  table.sort(keys)
  for _, key in ipairs(keys) do
    local expected = KEY_TYPES[key]
    if not expected then
      table.insert(problems, ("unknown setting '%s' (see lua/odoo/local.example.lua)"):format(key))
    elseif type(user[key]) ~= expected then
      local actual = type(user[key])
      table.insert(problems, ("'%s' must be a %s, not a %s (using the default)"):format(key, expected, actual))
      user[key] = nil
    end
  end
  return problems
end

--- Folders the user named that do not exist.
---@return string[] problems
local function check_folders()
  local problems = {}
  local function check(key, dir)
    if vim.fn.isdirectory(dir) == 0 then table.insert(problems, ("%s: no such folder: %s"):format(key, dir)) end
  end
  check("workspace", M.workspace)
  check("compose_dir", M.compose_dir)
  for _, dir in ipairs(M.own_addons) do
    check("own_addons", dir)
  end
  for _, dir in ipairs(M.addons_paths) do
    if dir ~= M.core_addons then check("addons_paths", dir) end -- core appears after :Odoo sync-core
  end
  return problems
end

local loaded = false

--- Fill the settings from `user` (default: what lua/odoo/local.lua returns).
---@param user? table values in the format of local.lua
---@return OdooSettings
function M.load(user)
  loaded = true
  local problems = {}
  if user then
    user = vim.deepcopy(user)
    M.configured = true
  else
    M.configured = vim.uv.fs_stat(M.local_file) ~= nil
    user = {}
    if M.configured then
      local problem
      user, problem = read_local_file()
      table.insert(problems, problem)
    end
  end
  vim.list_extend(problems, check_keys(user))

  local function opt(key, default)
    if user[key] ~= nil then return user[key] end
    return default
  end

  -- ---------------------------------------------------------------- your project
  -- Folder of the repo you work in. Default: the git repo of the folder nvim was started in.
  M.workspace = expand(opt("workspace", vim.fs.root(vim.fn.getcwd(), ".git") or vim.fn.getcwd()))

  -- Code you write: formatted with black on save, diagnostics shown. Default: the workspace.
  M.own_addons = expand_list(opt("own_addons", { M.workspace }))

  -- Odoo core source (the folder that CONTAINS odoo/, the python package).
  -- With Docker it is copied out of the container by :Odoo sync-core
  M.core = expand(opt("core", vim.fn.stdpath("data") .. "/odoo-core"))
  M.core_addons = expand(opt("core_addons", M.core .. "/odoo/addons")) -- sale, account, stock, web...

  -- Every addons folder (pickers: find model / xml id / grep, and the language server).
  -- A folder that holds REPOS of modules (e.g. oca/ with web/, server-tools/...) is fine too:
  -- each repo inside is used as an addons folder.
  M.addons_paths = expand_list(opt("addons_paths", vim.list_extend(vim.deepcopy(M.own_addons), { M.core_addons })))
  if not vim.tbl_contains(M.addons_paths, M.core_addons) then table.insert(M.addons_paths, M.core_addons) end

  -- Read-only code: you browse it, you don't edit it (nvim warns before saving).
  M.readonly_paths = expand_list(opt("readonly_paths", { M.core }))

  -- Python with Odoo's dependencies (lxml, werkzeug...) for the language servers. Optional.
  M.python = expand(opt("python", vim.fn.exepath("python3")))

  -- ---------------------------------------------------------------- docker
  -- Folder with docker-compose.yml. Default: the workspace.
  M.compose_dir = expand(opt("compose_dir", M.workspace))
  M.service = opt("service", "odoo") -- odoo service name in the compose file
  M.db_service = opt("db_service", "db") -- postgres service name
  M.container = opt("container", nil) -- nil = ask `docker compose` for it
  M.odoo_conf = opt("odoo_conf", "/etc/odoo/odoo.conf") -- path INSIDE the container
  M.odoo_bin = opt("odoo_bin", "/usr/bin/odoo") -- odoo executable INSIDE the container
  M.db_user = opt("db_user", "odoo")
  M.core_remote = opt("core_remote", "/usr/lib/python3/dist-packages/odoo") -- odoo package INSIDE the container
  M.core_image = opt("core_image", nil) -- image for :Odoo sync-core (nil = the service's)

  -- Database for update/install/test/shell. nil = the "-d" of the service `command:` in the
  -- compose file. Change at runtime with :Odoo db
  M.db = opt("db", nil)

  -- One-off odoo commands (update, tests, shell) run next to the live server, which already
  -- uses 8069/8072 inside the container, so they need other ports.
  M.oneoff_args = opt("oneoff_args", { "--http-port=8071", "--gevent-port=8073" })

  -- Debugger (debugpy). The port must be published in the compose file ("5678:5678").
  M.debug = vim.tbl_extend("force", { host = "127.0.0.1", port = 5678, extra_args = {} }, opt("debug", {}))

  -- Container path -> local path, most specific first: { { remote = "/mnt/x", ["local"] = "~/x" } }
  -- Used by the debugger (breakpoints) and to open tracebacks from the Odoo log.
  -- nil = read the volumes of the odoo service from the compose file (+ the core copy).
  M.path_mappings = nil
  if user.path_mappings then
    M.path_mappings = vim.tbl_map(
      function(mapping) return { remote = mapping.remote, ["local"] = expand(mapping["local"]) } end,
      user.path_mappings
    )
  end

  M.web_url = opt("web_url", "http://localhost:8069")

  -- ---------------------------------------------------------------- odoo-ls (language server)
  -- nil = an odools.toml is generated from the settings above (stdpath("state")/odoo/odools.toml).
  -- Or the path of your own odools.toml.
  local odools_config = opt("odools_config", nil)
  M.odools_config = odools_config and expand(odools_config) or nil
  M.odoo_ls_cmd = opt("odoo_ls_cmd", "odoo_ls_server")

  if M.configured then vim.list_extend(problems, check_folders()) end
  M.problems = problems
  return M
end

-- Reading any setting before load() was called loads local.lua first.
return setmetatable(M, {
  __index = function(_, key)
    if loaded then return nil end
    M.load()
    return rawget(M, key)
  end,
})
