-- Talks to the Odoo container through `docker compose` (run in settings.compose_dir).
local S = require("odoo.settings")
local log = require("odoo.log")
local M = {}

M.state = { db = nil } -- runtime choices (:Odoo db)

local function compose(args) return vim.list_extend({ "docker", "compose" }, args) end

local function sys(cmd, opts)
  local r = vim.system(cmd, vim.tbl_extend("force", { text = true, cwd = S.compose_dir }, opts or {})):wait()
  return r.code == 0, vim.trim(r.stdout or ""), vim.trim(r.stderr or "")
end

-- The compose file in settings.compose_dir (nil if there is none)
function M.compose_file()
  for _, name in ipairs({ "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml" }) do
    if vim.uv.fs_stat(S.compose_dir .. "/" .. name) then return name end
  end
end

-- The odoo service as docker compose sees it: { command = {...}, volumes = {...}, image = "..." }
local service_cache
function M.service_config()
  if service_cache then return service_cache end
  if not M.compose_file() then return {} end
  local ok, out = sys(compose({ "config", "--format", "json" }))
  if ok then
    local okj, cfg = pcall(vim.json.decode, out, { luanil = { object = true, array = true } })
    if okj and cfg.services and cfg.services[S.service] then service_cache = cfg.services[S.service] end
  end
  return service_cache or {}
end

-- The service `command:`, e.g. { "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "mydb" }
function M.compose_command() return M.service_config().command end

-- Container name/id of the odoo service
function M.container()
  if S.container then return S.container end
  local ok, out = sys(compose({ "ps", "-aq", S.service }))
  local id = ok and vim.split(out, "\n")[1] or ""
  return id ~= "" and id or (S.service .. " (not created)")
end

function M.db()
  if M.state.db then return M.state.db end
  if S.db then return S.db end
  local cmd = M.compose_command() or {}
  for i, a in ipairs(cmd) do
    if a == "-d" or a == "--database" then return cmd[i + 1] end
    local v = a:match("^%-%-database=(.+)") or a:match("^%-d(.+)")
    if v then return v end
  end
  return "odoo"
end

--- { exists, running, debug }
function M.status()
  local ok, out = sys({ "docker", "inspect", "-f", "{{.State.Running}}|{{json .Config.Cmd}}", M.container() })
  if not ok then return { exists = false, running = false, debug = false } end
  local running, cmd = out:match("^(%a+)|(.*)$")
  return { exists = true, running = running == "true", debug = (cmd or ""):find("debugpy", 1, true) ~= nil }
end

-- ------------------------------------------------------------------ one-off odoo commands
local function odoo_oneoff(extra)
  local cmd = compose({ "exec", "-T", S.service, "odoo", "-c", S.odoo_conf, "-d", M.db() })
  vim.list_extend(cmd, extra)
  vim.list_extend(cmd, S.oneoff_args)
  return cmd
end

--- Restart the server. If the debugger was attached, it re-attaches by itself.
function M.restart(cb)
  local was_debugging = package.loaded["dap"] and require("dap").session() ~= nil
  log.run({
    title = "restart",
    cmd = compose({ "restart", S.service }),
    cwd = S.compose_dir,
    quickfix = false,
    on_exit = function(code)
      if code == 0 then
        vim.notify("Odoo restarted")
        if was_debugging then
          vim.notify("Re-attaching debugger…")
          M.wait_debugpy(function() require("odoo").attach() end)
        end
      end
      if cb then cb(code) end
    end,
  })
end

--- -u module (applies XML/data/fields). restart=true also reloads Python code in the server.
function M.update(module, restart)
  vim.cmd("silent! wall")
  log.run({
    title = "update " .. module,
    cmd = odoo_oneoff({ "-u", module, "--stop-after-init" }),
    cwd = S.compose_dir,
    on_exit = function(code)
      if code ~= 0 then
        vim.notify("Update of " .. module .. " FAILED (see panel / <Space>xq)", vim.log.levels.ERROR)
      elseif restart then
        vim.notify("Updated " .. module .. ", restarting server…")
        M.restart()
      else
        vim.notify("Updated " .. module .. " ✔")
      end
    end,
  })
end

function M.install(module)
  vim.cmd("silent! wall")
  log.run({
    title = "install " .. module,
    cmd = odoo_oneoff({ "-i", module, "--stop-after-init" }),
    cwd = S.compose_dir,
    on_exit = function(code)
      if code == 0 then
        vim.notify("Installed " .. module .. ", restarting server…")
        M.restart()
      else
        vim.notify("Install of " .. module .. " FAILED", vim.log.levels.ERROR)
      end
    end,
  })
end

--- tag examples: "/my_module"  "/my_module:TestFoo"  "/my_module:TestFoo.test_bar"
function M.test(module, tag)
  vim.cmd("silent! wall")
  tag = tag or ("/" .. module)
  log.run({
    title = "test " .. tag,
    cmd = odoo_oneoff({ "-u", module, "--test-enable", "--test-tags", tag, "--log-level=test", "--stop-after-init" }),
    cwd = S.compose_dir,
    on_exit = function(code, lines)
      local summary
      for i = #lines, 1, -1 do
        local l = lines[i]
        if l:match("failed, %d+ error") or l:match("tests? in") then
          summary = l:gsub("^.-: ", "")
          break
        end
      end
      local failed = code ~= 0
      for _, l in ipairs(lines) do
        if l:match("^FAIL:") or l:match("^ERROR:") or l:match(" ERROR .*odoo%.tests") then failed = true end
      end
      vim.notify((failed and "✘ Tests FAILED" or "✔ Tests passed") .. (summary and ("\n" .. summary) or ""),
        failed and vim.log.levels.ERROR or vim.log.levels.INFO)
    end,
  })
end

function M.logs()
  log.run({
    title = "logs",
    cmd = compose({ "logs", "-f", "--tail=300", S.service }),
    cwd = S.compose_dir,
    quickfix = false,
  })
end

function M.up(cb)
  log.run({
    title = "start",
    cmd = compose({ "up", "-d", S.service }),
    cwd = S.compose_dir,
    quickfix = false,
    on_exit = function(code)
      if code == 0 then vim.notify("Odoo running (normal mode) → " .. S.web_url) end
      if cb then cb(code) end
    end,
  })
end

function M.stop()
  log.run({ title = "stop", cmd = compose({ "stop", S.service }), cwd = S.compose_dir, quickfix = false })
end

-- Interactive things open in a terminal
local function term(cmd, title)
  Snacks.terminal(cmd, { cwd = S.compose_dir, win = { position = "bottom", height = 0.4, title = title } })
end

function M.shell()
  local cmd = compose({ "exec", S.service, "odoo", "shell", "-c", S.odoo_conf, "-d", M.db(), "--no-http" })
  term(vim.list_extend(cmd, S.oneoff_args), "odoo shell")
end
function M.psql() term(compose({ "exec", S.db_service, "psql", "-U", S.db_user, "-d", M.db() }), "psql") end
function M.bash() term(compose({ "exec", S.service, "bash" }), "container bash") end

function M.pick_db()
  local ok, out = sys(compose({ "exec", "-T", S.db_service, "psql", "-U", S.db_user, "-d", "postgres", "-Atc",
    "select datname from pg_database where not datistemplate and datname <> 'postgres' order by 1" }))
  if not ok then
    vim.notify("Is the db container running? (" .. out .. ")", vim.log.levels.ERROR)
    return
  end
  vim.ui.select(vim.split(out, "\n", { trimempty = true }), { prompt = "Database (now: " .. M.db() .. ")" },
    function(choice)
      if choice then
        M.state.db = choice
        vim.notify("Odoo DB for nvim commands: " .. choice)
      end
    end)
end

-- ------------------------------------------------------------------ debug mode
-- Debug mode = the same command as docker-compose.yml, but started through debugpy, using an
-- override file generated in nvim's state dir. `:Odoo start` goes back to normal mode.
function M.debug_override_file()
  local cmd = vim.deepcopy(M.compose_command() or {})
  if cmd[1] == "odoo" or cmd[1] == S.odoo_bin then table.remove(cmd, 1) end
  local full = { "python3", "-m", "debugpy", "--listen", "0.0.0.0:" .. S.debug.port, S.odoo_bin }
  vim.list_extend(full, cmd)
  vim.list_extend(full, S.debug.extra_args)
  local dir = vim.fn.stdpath("state") .. "/odoo"
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/docker-compose.debug.yml"
  vim.fn.writefile({
    "# Generated by nvim (lua/odoo/docker.lua). Do not edit: it is rewritten on every :Odoo debug",
    "services:",
    "  " .. S.service .. ":",
    "    command: " .. vim.json.encode(full),
  }, file)
  return file
end

--- Calls cb() once debugpy accepts connections inside the container.
function M.wait_debugpy(cb, tries)
  tries = tries or 90
  -- Don't connect to the port to test it: debugpy takes the first connection as its client and
  -- then ignores the real one. Instead look for a LISTEN socket on the port in /proc/net/tcp.
  local probe = ("grep -q ':%04X 00000000:0000 0A' /proc/net/tcp /proc/net/tcp6"):format(S.debug.port)
  vim.system({ "docker", "exec", M.container(), "sh", "-c", probe }, {}, function(r)
    vim.schedule(function()
      if r.code == 0 then
        cb()
      elseif tries > 0 then
        vim.defer_fn(function() M.wait_debugpy(cb, tries - 1) end, 1000)
      else
        vim.notify("debugpy did not start, check :Odoo logs", vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.debug_up(cb)
  local file = M.debug_override_file()
  vim.notify("Restarting Odoo in DEBUG mode…")
  log.run({
    title = "start debug",
    cmd = compose({ "-f", M.compose_file() or "docker-compose.yml", "-f", file, "up", "-d", S.service }),
    cwd = S.compose_dir,
    quickfix = false,
    on_exit = function(code)
      if code ~= 0 then
        vim.notify("Could not start debug mode", vim.log.levels.ERROR)
        return
      end
      M.wait_debugpy(cb)
    end,
  })
end

return M
