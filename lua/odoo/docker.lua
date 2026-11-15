-- Odoo actions in the editor: runs the commands of lua/odoo/compose.lua in the log panel
-- (or a terminal for the interactive ones) and tells you how they ended.
local settings = require("odoo.settings")
local compose = require("odoo.compose")
local log = require("odoo.log")
local M = {}

-- What the compose file says (kept here so callers need one module for "docker things").
M.state = compose.state
M.compose_file = compose.compose_file
M.service_config = compose.service_config
M.compose_command = compose.command
M.container = compose.container
M.db = compose.db
M.status = compose.status
M.debug_override_file = compose.debug_override_file

--- Run a compose command in the log panel.
---@param title string
---@param cmd string[]
---@param opts? { on_exit?: fun(code: integer, lines: string[]), quickfix?: boolean }
local function run(title, cmd, opts)
  return log.run(vim.tbl_extend("force", { title = title, cmd = cmd, cwd = settings.compose_dir }, opts or {}))
end

--- Run a command whose output has no tracebacks worth collecting (start, stop, logs...).
local function run_plain(title, cmd, on_exit) return run(title, cmd, { quickfix = false, on_exit = on_exit }) end

--- Restart the server. If the debugger was attached, it re-attaches by itself.
---@param on_done? fun(code: integer)
function M.restart(on_done)
  local was_debugging = package.loaded["dap"] and require("dap").session() ~= nil
  run_plain("restart", compose.argv.restart(), function(code)
    if code == 0 then
      vim.notify("Odoo restarted")
      if was_debugging then
        vim.notify("Re-attaching debugger…")
        M.wait_debugpy(function() require("odoo").attach() end)
      end
    end
    if on_done then on_done(code) end
  end)
end

--- Save everything, run an update or install of `module`, then report and maybe restart.
---@param action "update"|"install"
---@param module string
---@param restart boolean reload Python code in the server afterwards
local function change_module(action, module, restart)
  local done = action == "update" and "Updated " or "Installed "
  vim.cmd("silent! wall")
  run(action .. " " .. module, compose.argv[action](module), {
    on_exit = function(code)
      if code ~= 0 then
        local failed = (action == "update" and "Update of " or "Install of ") .. module .. " FAILED"
        vim.notify(failed .. " (see panel / <Space>xq)", vim.log.levels.ERROR)
      elseif restart then
        vim.notify(done .. module .. ", restarting server…")
        M.restart()
      else
        vim.notify(done .. module .. " ✔")
      end
    end,
  })
end

--- -u module (applies XML/data/fields). restart=true also reloads Python code in the server.
---@param module string
---@param restart boolean
function M.update(module, restart) change_module("update", module, restart) end

---@param module string
function M.install(module) change_module("install", module, true) end

--- tag examples: "/my_module"  "/my_module:TestFoo"  "/my_module:TestFoo.test_bar"
---@param module string
---@param tag? string
function M.test(module, tag)
  vim.cmd("silent! wall")
  tag = tag or ("/" .. module)
  run("test " .. tag, compose.argv.test(module, tag), {
    on_exit = function(code, lines)
      local result = require("odoo.tests").result(code, lines)
      local message = (result.failed and "✘ Tests FAILED" or "✔ Tests passed")
        .. (result.summary and ("\n" .. result.summary) or "")
      vim.notify(message, result.failed and vim.log.levels.ERROR or vim.log.levels.INFO)
    end,
  })
end

function M.logs() run_plain("logs", compose.argv.logs()) end

---@param on_done? fun(code: integer)
function M.up(on_done)
  run_plain("start", compose.argv.up(), function(code)
    if code == 0 then vim.notify("Odoo running (normal mode) → " .. settings.web_url) end
    if on_done then on_done(code) end
  end)
end

function M.stop() run_plain("stop", compose.argv.stop()) end

--- Interactive things open in a terminal.
---@param cmd string[]
---@param title string
local function terminal(cmd, title)
  Snacks.terminal(cmd, { cwd = settings.compose_dir, win = { position = "bottom", height = 0.4, title = title } })
end

function M.shell() terminal(compose.argv.shell(), "odoo shell") end
function M.psql() terminal(compose.argv.psql(), "psql") end
function M.bash() terminal(compose.argv.bash(), "container bash") end

--- Choose the database the commands above work on.
function M.pick_db()
  local names, err = compose.databases()
  if not names then
    vim.notify("Is the db container running? (" .. err .. ")", vim.log.levels.ERROR)
    return
  end
  vim.ui.select(names, { prompt = "Database (now: " .. compose.db() .. ")" }, function(choice)
    if choice then
      compose.state.db = choice
      vim.notify("Odoo DB for nvim commands: " .. choice)
    end
  end)
end

--- Calls on_ready() once debugpy accepts connections inside the container.
---@param on_ready fun()
---@param tries? integer seconds left to wait (default 90)
function M.wait_debugpy(on_ready, tries)
  tries = tries or 90
  local function retry()
    if tries > 0 then
      vim.defer_fn(function() M.wait_debugpy(on_ready, tries - 1) end, 1000)
    else
      vim.notify("debugpy did not start, check :Odoo logs", vim.log.levels.ERROR)
    end
  end
  local probe = compose.argv.debugpy_probe()
  if not probe then return retry() end -- the container is still being created
  vim.system(probe, {}, function(result)
    vim.schedule(function()
      if result.code == 0 then return on_ready() end
      retry()
    end)
  end)
end

--- Restart Odoo under debugpy, then call on_ready() when the debugger can attach.
---@param on_ready fun()
function M.debug_up(on_ready)
  vim.notify("Restarting Odoo in DEBUG mode…")
  run_plain("start debug", compose.argv.debug_up(compose.debug_override_file()), function(code)
    if code ~= 0 then
      vim.notify("Could not start debug mode", vim.log.levels.ERROR)
      return
    end
    M.wait_debugpy(on_ready)
  end)
end

return M
