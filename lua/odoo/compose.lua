-- `docker compose` knowledge that needs no editor UI: what the compose file says (service,
-- command, volumes, database) and the argument lists of every Odoo action.
-- Nothing here notifies, opens windows or needs a plugin, so the command line tool
-- (scripts/cli.lua) and the tests use it as-is. The editor side is lua/odoo/docker.lua.
local settings = require("odoo.settings")
local M = {}

---@class OdooComposeState
---@field db? string database chosen at runtime (:Odoo db)
M.state = { db = nil }

--- `docker compose <args>` as an argument list.
---@param args string[]
---@return string[]
function M.compose(args) return vim.list_extend({ "docker", "compose" }, args) end

--- Run a command in settings.compose_dir and wait for it.
---@param cmd string[]
---@return boolean ok, string stdout, string stderr
function M.run_sync(cmd)
  local result = vim.system(cmd, { text = true, cwd = settings.compose_dir }):wait()
  return result.code == 0, vim.trim(result.stdout or ""), vim.trim(result.stderr or "")
end

--- Name of the compose file in settings.compose_dir (nil if there is none).
---@return string?
function M.compose_file()
  for _, name in ipairs({ "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml" }) do
    if vim.uv.fs_stat(settings.compose_dir .. "/" .. name) then return name end
  end
end

local service_cache

--- The odoo service as docker compose resolves it: { command = {...}, volumes = {...}, image = "..." }.
---@return table
function M.service_config()
  if service_cache then return service_cache end
  if not M.compose_file() then return {} end
  local ok, out = M.run_sync(M.compose({ "config", "--format", "json" }))
  if ok then
    local decoded, config = pcall(vim.json.decode, out, { luanil = { object = true, array = true } })
    if decoded and config.services and config.services[settings.service] then
      service_cache = config.services[settings.service]
    end
  end
  return service_cache or {}
end

--- The service `command:`, e.g. { "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "mydb" }.
---@return string[]?
function M.command() return M.service_config().command end

local container_id

--- Container name or id of the odoo service (nil while it is not created): settings.container,
--- else the `container_name:` of the compose file, else what `docker compose ps` says.
--- The answer is remembered until forget_container().
---@return string?
function M.container()
  if settings.container then return settings.container end
  if not container_id then
    container_id = M.service_config().container_name
    if not container_id then
      local ok, out = M.run_sync(M.compose({ "ps", "-aq", settings.service }))
      local id = ok and vim.split(out, "\n")[1] or ""
      container_id = id ~= "" and id or nil
    end
  end
  return container_id
end

--- The container was (re)created or removed: look it up again next time.
function M.forget_container() container_id = nil end

--- Database for update / install / test / shell: the runtime choice, else settings.db,
--- else the `-d` of the compose command, else "odoo".
---@return string
function M.db()
  if M.state.db then return M.state.db end
  if settings.db then return settings.db end
  local command = M.command() or {}
  for i, arg in ipairs(command) do
    if arg == "-d" or arg == "--database" then return command[i + 1] end
    local value = arg:match("^%-%-database=(.+)") or arg:match("^%-d(.+)")
    if value then return value end
  end
  return "odoo"
end

---@class OdooContainerStatus
---@field exists boolean
---@field running boolean
---@field debug boolean started under debugpy

---@return OdooContainerStatus
function M.status()
  local missing = { exists = false, running = false, debug = false }
  local container = M.container()
  if not container then return missing end
  local ok, out = M.run_sync({ "docker", "inspect", "-f", "{{.State.Running}}|{{json .Config.Cmd}}", container })
  if not ok then return missing end
  local running, command = out:match("^(%a+)|(.*)$")
  return { exists = true, running = running == "true", debug = (command or ""):find("debugpy", 1, true) ~= nil }
end

--- Databases of the postgres service.
---@return string[]? names, string? error
function M.databases()
  local query = "select datname from pg_database where not datistemplate and datname <> 'postgres' order by 1"
  local ok, out, err = M.run_sync(M.argv.psql_query(query))
  if not ok then return nil, err ~= "" and err or out end
  return vim.split(out, "\n", { trimempty = true })
end

-- ------------------------------------------------------------------ argument lists
-- One function per action. Each returns the full command to run in settings.compose_dir.
local argv = {}
M.argv = argv

--- A one-off `odoo` process next to the live server (which keeps the default ports).
---@param extra string[]
---@return string[]
local function oneoff(extra)
  local cmd = M.compose({ "exec", "-T", settings.service, "odoo", "-c", settings.odoo_conf, "-d", M.db() })
  vim.list_extend(cmd, extra)
  return vim.list_extend(cmd, settings.oneoff_args)
end

---@param module string
function argv.update(module) return oneoff({ "-u", module, "--stop-after-init" }) end

---@param module string
function argv.install(module) return oneoff({ "-i", module, "--stop-after-init" }) end

--- tag examples: "/my_module"  "/my_module:TestFoo"  "/my_module:TestFoo.test_bar"
---@param module string
---@param tag? string default: every test of the module
function argv.test(module, tag)
  tag = tag or ("/" .. module)
  return oneoff({ "-u", module, "--test-enable", "--test-tags", tag, "--log-level=test", "--stop-after-init" })
end

function argv.restart() return M.compose({ "restart", settings.service }) end
function argv.up() return M.compose({ "up", "-d", settings.service }) end
function argv.stop() return M.compose({ "stop", settings.service }) end

---@param opts? { tail?: integer, follow?: boolean } default: follow the last 300 lines
function argv.logs(opts)
  opts = opts or {}
  local cmd = M.compose({ "logs", "--tail=" .. (opts.tail or 300) })
  if opts.follow ~= false then table.insert(cmd, "-f") end
  table.insert(cmd, settings.service)
  return cmd
end

function argv.shell()
  local cmd =
    M.compose({ "exec", settings.service, "odoo", "shell", "-c", settings.odoo_conf, "-d", M.db(), "--no-http" })
  return vim.list_extend(cmd, settings.oneoff_args)
end

function argv.psql() return M.compose({ "exec", settings.db_service, "psql", "-U", settings.db_user, "-d", M.db() }) end

---@param query string
function argv.psql_query(query)
  return M.compose({
    "exec",
    "-T",
    settings.db_service,
    "psql",
    "-U",
    settings.db_user,
    "-d",
    "postgres",
    "-Atc",
    query,
  })
end

function argv.bash() return M.compose({ "exec", settings.service, "bash" }) end

--- Start the service with the debug override file on top of the compose file.
---@param override_file string
function argv.debug_up(override_file)
  return M.compose({ "-f", M.compose_file() or "docker-compose.yml", "-f", override_file, "up", "-d", settings.service })
end

--- Succeeds once debugpy listens inside the container. It does not connect to the port:
--- debugpy takes the first connection as its client and then ignores the real one, so the
--- probe looks for a LISTEN socket in /proc/net/tcp instead.
---@return string[]? nil while the container does not exist
function argv.debugpy_probe()
  local container = M.container()
  if not container then return nil end
  local probe = ("grep -q ':%04X 00000000:0000 0A' /proc/net/tcp /proc/net/tcp6"):format(settings.debug.port)
  return { "docker", "exec", container, "sh", "-c", probe }
end

-- ------------------------------------------------------------------ debug mode
-- Debug mode = the same command as the compose file, but started through debugpy, using an
-- override file generated in nvim's state dir. The user's compose file is never touched.

--- Is `arg` the Odoo executable: `odoo`, `odoo-bin` (whatever the folder) or `extra` (settings.odoo_bin)?
---@param arg string
---@param extra? string
---@return boolean
function M.is_odoo_executable(arg, extra)
  local name = vim.fs.basename(arg)
  return name == "odoo" or name == "odoo-bin" or (extra ~= nil and arg == extra)
end

--- The compose command wrapped in debugpy.
---@return string[]
function M.debug_command()
  local command = M.command() or {}
  -- The user's compose file may already run debugpy (it does here). Keep only the Odoo
  -- arguments after the Odoo binary, otherwise `odoo` gets "python3" as a sub-command.
  local args, python_options = command, {}
  for i, arg in ipairs(command) do
    if M.is_odoo_executable(arg, settings.odoo_bin) then
      args = vim.list_slice(command, i + 1)
      -- `python3 -Xfrozen_modules=off -m debugpy ...`: keep the interpreter options debugpy asked for
      if vim.fs.basename(command[1]):match("^python") then
        for j = 2, i - 1 do
          if command[j] == "-m" and command[j + 1] == "debugpy" then
            python_options = vim.list_slice(command, 2, j - 1)
            break
          end
        end
      end
      break
    end
  end
  local full = { "python3" }
  vim.list_extend(full, python_options)
  vim.list_extend(full, { "-m", "debugpy", "--listen", "0.0.0.0:" .. settings.debug.port, settings.odoo_bin })
  vim.list_extend(full, args)
  return vim.list_extend(full, settings.debug.extra_args)
end

--- Write the override file and return its path.
---@return string
function M.debug_override_file()
  local dir = vim.fn.stdpath("state") .. "/odoo"
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/docker-compose.debug.yml"
  vim.fn.writefile({
    "# Generated by nvim (lua/odoo/compose.lua). Do not edit: it is rewritten on every :Odoo debug",
    "services:",
    "  " .. settings.service .. ":",
    "    command: " .. vim.json.encode(M.debug_command()),
  }, file)
  return file
end

--- Forget what was read from the compose file (after it changed).
function M.reset()
  service_cache, container_id = nil, nil
end

return M
