-- ============================================================================
--  Odoo project settings = the defaults below + YOUR values from lua/odoo/local.lua
--
--  Don't edit this file: run  :Odoo config  (creates/opens lua/odoo/local.lua, which is
--  git-ignored) and set your paths there. See lua/odoo/local.example.lua for every option.
-- ============================================================================
local M = {}

local function ex(p) return p and vim.fs.normalize(vim.fn.expand(p)) or nil end
local function ex_list(t) return vim.tbl_map(ex, t or {}) end

M.local_file = vim.fn.stdpath("config") .. "/lua/odoo/local.lua"
M.example_file = vim.fn.stdpath("config") .. "/lua/odoo/local.example.lua"

-- ---------------------------------------------------------------- load local.lua
local user = {}
M.configured = vim.uv.fs_stat(M.local_file) ~= nil
if M.configured then
  local ok, res = pcall(dofile, M.local_file)
  if ok and type(res) == "table" then
    user = res
  else
    vim.schedule(
      function()
        vim.notify("lua/odoo/local.lua has an error (using defaults):\n" .. tostring(res), vim.log.levels.ERROR)
      end
    )
  end
end
local function opt(key, default)
  if user[key] ~= nil then return user[key] end
  return default
end

-- ---------------------------------------------------------------- your project
-- Folder of the repo you work in. Default: the git repo of the folder nvim was started in.
M.workspace = ex(opt("workspace", vim.fs.root(vim.fn.getcwd(), ".git") or vim.fn.getcwd()))

-- Code you write: formatted with black on save, diagnostics shown. Default: the workspace.
M.own_addons = ex_list(opt("own_addons", { M.workspace }))

-- Odoo core source (the folder that CONTAINS odoo/, the python package).
-- With Docker it is copied out of the container by :Odoo sync-core
M.core = ex(opt("core", vim.fn.stdpath("data") .. "/odoo-core"))
M.core_addons = ex(opt("core_addons", M.core .. "/odoo/addons")) -- sale, account, stock, web...

-- Every addons folder (pickers: find model / xml id / grep, and the language server).
-- A folder that holds REPOS of modules (e.g. oca/ with web/, server-tools/...) is fine too:
-- each repo inside is used as an addons folder.
M.addons_paths = ex_list(opt("addons_paths", vim.list_extend(vim.deepcopy(M.own_addons), { M.core_addons })))
if not vim.tbl_contains(M.addons_paths, M.core_addons) then table.insert(M.addons_paths, M.core_addons) end

-- Read-only code: you browse it, you don't edit it (nvim warns before saving).
M.readonly_paths = ex_list(opt("readonly_paths", { M.core }))

-- Python with Odoo's dependencies (lxml, werkzeug...) for the language servers. Optional.
M.python = ex(opt("python", vim.fn.exepath("python3")))

-- ---------------------------------------------------------------- docker
-- Folder with docker-compose.yml. Default: the workspace.
M.compose_dir = ex(opt("compose_dir", M.workspace))
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
M.debug = vim.tbl_extend("force", {
  host = "127.0.0.1",
  port = 5678,
  extra_args = {}, -- extra odoo args only in debug mode, e.g. { "--dev=xml" }
}, opt("debug", {}))

-- Container path -> local path, most specific first: { { remote = "/mnt/x", ["local"] = "~/x" } }
-- Used by the debugger (breakpoints) and to open tracebacks from the Odoo log.
-- nil = read the volumes of the odoo service from the compose file (+ the core copy).
M.path_mappings = user.path_mappings
    and vim.tbl_map(function(m) return { remote = m.remote, ["local"] = ex(m["local"]) } end, user.path_mappings)
  or nil

M.web_url = opt("web_url", "http://localhost:8069")

-- ---------------------------------------------------------------- odoo-ls (language server)
-- nil = an odools.toml is generated from the settings above (stdpath("state")/odoo/odools.toml).
-- Or the path of your own odools.toml.
M.odools_config = ex(opt("odools_config", nil))
M.odoo_ls_cmd = opt("odoo_ls_cmd", "odoo_ls_server")

return M
