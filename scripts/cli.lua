-- `odoo-nvim`: the Odoo commands of this config without the editor. See usage() below.
-- Run through scripts/odoo-nvim (nvim -u NONE -l scripts/cli.lua ...): only the plugin-free
-- modules of lua/odoo are loaded, with the settings of lua/odoo/local.lua.
local repo = vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(arg[0]))))
package.path = repo .. "/lua/?.lua;" .. package.path

local settings = require("odoo.settings")
local compose = require("odoo.compose")
local paths = require("odoo.paths")
local traceback = require("odoo.traceback")
local last_run = require("odoo.last_run")

local USAGE = [[
odoo-nvim <command> [options]      Odoo commands of the Neovim config, from a terminal

Work on a module (output is streamed with local file paths; the last line is RESULT: ...):
  update <module> [--no-restart]   -u the module, then restart the server (Python + XML changes)
  install <module>                 -i the module, then restart the server
  test <module>                    run the tests of a module
  test /<module>:<Class>[.<method>]   run one test class or method
      --json                       print one JSON object instead of the output
      --db <name>                  another database than the configured one

Server:
  start | stop | restart           the Odoo container
  logs [--tail N] [--follow]       server log (default: last 200 lines)
  last                             output of the last update / install / test
  dbs                              databases of the postgres service

Front-end files (no Docker needed; run it after you write JS, XML templates or SCSS):
  frontend [<module>] [--json]     are the files under static/src loaded by a bundle of the manifest,
                                   do the bundle entries exist, does every `static template` have its t-name
                                   (default: every addon of your own folders)

Setup and status:
  setup --workspace DIR [--compose-dir DIR] [--own DIR]... [--core DIR] [--python PATH]
        [--service NAME] [--db-service NAME] [--force] [--print]
                                   write lua/odoo/local.lua from what the project says (also the Odoo binary,
                                   debug port, web port and a .venv python)
                                   (--print: show it, write nothing; --force: replace it)
  brief [--write]                  the instructions for AI agents working in the addons repo
                                   (--write: put them into its AGENTS.md / CLAUDE.md)
  info [--json]                    what is configured: folders, container, database
  doctor [--json]                  check programs, settings, compose file, container

Exit code: 0 = ok, 1 = failed, 2 = wrong usage.]]

local VALUE_FLAGS = { tail = true, db = true, workspace = true, python = true, core = true, service = true }
VALUE_FLAGS["compose-dir"] = true
VALUE_FLAGS["db-service"] = true
local LIST_FLAGS = { own = true }

local function out(...) io.stdout:write(...) end
local function say(text) io.stdout:write(text, "\n") end

---@param message string
---@param code? integer
local function die(message, code)
  io.stderr:write("odoo-nvim: ", message, "\n")
  os.exit(code or 1)
end

--- `value`, or stop with `message` when there is none.
---@generic T
---@param value T?
---@param message string
---@param code? integer
---@return T
local function need(value, message, code)
  if value == nil then die(message, code) end
  ---@diagnostic disable-next-line: return-type-mismatch
  return value
end

--- Split the arguments into positional ones and --flags.
---@param args string[]
---@return string[] positional, table<string, any> flags
local function parse(args)
  local positional, flags = {}, {}
  local i = 1
  while i <= #args do
    local name, value = args[i]:match("^%-%-([%w-]+)=?(.*)$")
    if not name then
      table.insert(positional, args[i])
    elseif VALUE_FLAGS[name] or LIST_FLAGS[name] then
      if value == "" then
        i = i + 1
        value = args[i]
      end
      if not value then die("--" .. name .. " needs a value", 2) end
      if LIST_FLAGS[name] then
        flags[name] = flags[name] or {}
        table.insert(flags[name], value)
      else
        flags[name] = value
      end
    else
      flags[name] = true
    end
    i = i + 1
  end
  return positional, flags
end

local function require_settings()
  if not settings.configured then die("not configured yet: run `odoo-nvim setup --workspace DIR` first") end
end

--- Run a command in the compose folder, printing its output with local paths as it comes.
---@param cmd string[]
---@param quiet? boolean collect the output without printing it
---@return integer code, string[] lines
local function stream(cmd, quiet)
  paths.mappings() -- read the compose file now: the callbacks below must not start processes
  local lines, partial = {}, ""
  local function on_data(_, data)
    if not data then return end
    partial = partial .. data
    while true do
      local newline = partial:find("\n", 1, true)
      if not newline then break end
      local line = partial:sub(1, newline - 1):gsub("\r$", "")
      partial = partial:sub(newline + 1)
      table.insert(lines, line)
      if not quiet then out(traceback.localize(line), "\n") end
    end
  end
  local ran, job =
    pcall(vim.system, cmd, { cwd = settings.compose_dir, text = true, stdout = on_data, stderr = on_data })
  if not ran then die(cmd[1] .. " could not be started: " .. tostring(job)) end
  local code = job:wait().code
  if partial ~= "" then on_data(nil, "\n") end
  return code, lines
end

--- Number of ERROR / CRITICAL lines Odoo logged.
local function count_log_errors(lines)
  local count = 0
  for _, line in ipairs(lines) do
    if line:match("%d ERROR ") or line:match("%d CRITICAL ") then count = count + 1 end
  end
  return count
end

--- Print how an update / install / test ended, as text or JSON, and exit.
---@param report { command: string, target: string, ok: boolean, code: integer, lines: string[], summary?: string }
---@param as_json boolean
local function finish(report, as_json)
  local problems = {}
  for _, item in ipairs(traceback.to_qf(report.lines)) do
    if item.filename then table.insert(problems, { file = item.filename, line = item.lnum, text = item.text }) end
  end
  local log_errors = count_log_errors(report.lines)
  if as_json then
    say(vim.json.encode({
      command = report.command,
      target = report.target,
      ok = report.ok,
      exit_code = report.code,
      summary = report.summary,
      log_errors = log_errors,
      problems = problems,
      log = last_run.file(),
    }))
  else
    if #problems > 0 then
      say("\nProblem locations (your code first):")
      for i = 1, math.min(#problems, 20) do
        say(("  %s:%d  %s"):format(problems[i].file, problems[i].line, problems[i].text))
      end
    end
    local details = {}
    if report.summary then table.insert(details, report.summary) end
    if log_errors > 0 then table.insert(details, log_errors .. " error line(s) in the log") end
    if not report.ok then table.insert(details, "full output: odoo-nvim last") end
    local tail = #details > 0 and (" (" .. table.concat(details, "; ") .. ")") or ""
    say(("\nRESULT: %s %s %s%s"):format(report.ok and "ok" or "failed", report.command, report.target, tail))
  end
  os.exit(report.ok and 0 or 1)
end

local commands = {}

---@param action "update"|"install"
local function change_module(action, args, flags)
  require_settings()
  local module = need(args[1], action .. " needs a module name", 2)
  local cmd = compose.argv[action](module)
  local code, lines = stream(cmd, flags.json)
  last_run.save(cmd, lines, code)
  local ok = code == 0
  if ok and not flags["no-restart"] then
    local restart_code, restart_lines = stream(compose.argv.restart(), flags.json)
    ok = restart_code == 0
    vim.list_extend(lines, restart_lines)
  end
  finish({ command = action, target = module, ok = ok, code = code, lines = lines }, flags.json)
end

function commands.update(args, flags) change_module("update", args, flags) end
function commands.install(args, flags) change_module("install", args, flags) end

function commands.test(args, flags)
  require_settings()
  local target = need(args[1], "test needs a module name or a tag like /module:TestClass.test_method", 2)
  local module = target:match("^/([^:]+)") or target
  local tag = target:sub(1, 1) == "/" and target or ("/" .. target)
  local cmd = compose.argv.test(module, tag)
  local code, lines = stream(cmd, flags.json)
  last_run.save(cmd, lines, code)
  local result = require("odoo.tests").result(code, lines)
  finish(
    { command = "test", target = tag, ok = not result.failed, code = code, lines = lines, summary = result.summary },
    flags.json
  )
end

---@param action "start"|"stop"|"restart"
local function service_action(action)
  return function()
    require_settings()
    local code = stream(compose.argv[action == "start" and "up" or action]())
    say(("RESULT: %s %s"):format(code == 0 and "ok" or "failed", action))
    os.exit(code == 0 and 0 or 1)
  end
end
commands.start = service_action("start")
commands.stop = service_action("stop")
commands.restart = service_action("restart")

function commands.logs(_, flags)
  require_settings()
  local code = stream(compose.argv.logs({ tail = tonumber(flags.tail) or 200, follow = flags.follow == true }))
  os.exit(code == 0 and 0 or 1)
end

function commands.last()
  local lines = need(last_run.read(), "nothing ran yet (update, install or test)")
  say(table.concat(lines, "\n"))
end

function commands.dbs()
  require_settings()
  local names, problem = compose.databases()
  say(table.concat(need(names, "is the db container running? " .. (problem or "")), "\n"))
end

function commands.info(_, flags)
  local status = compose.status()
  local info = {
    configured = settings.configured,
    settings_file = settings.local_file,
    problems = settings.problems,
    workspace = settings.workspace,
    own_addons = settings.own_addons,
    addons_dirs = paths.addon_dirs(),
    readonly_paths = settings.readonly_paths,
    core = settings.core,
    odoo_version = paths.odoo_version(),
    compose_dir = settings.compose_dir,
    service = settings.service,
    container = compose.container(),
    container_status = not status.exists and "not created" or status.running and "running" or "stopped",
    debug_mode = status.debug,
    database = compose.db(),
    web_url = settings.web_url,
    last_run_log = last_run.file(),
  }
  if flags.json then return say(vim.json.encode(info)) end
  local order = {
    "configured",
    "settings_file",
    "workspace",
    "own_addons",
    "readonly_paths",
    "addons_dirs",
    "core",
    "odoo_version",
    "compose_dir",
    "service",
    "container",
    "container_status",
    "debug_mode",
    "database",
    "web_url",
    "last_run_log",
  }
  for _, key in ipairs(order) do
    local value = info[key]
    if type(value) == "table" then value = #value <= 4 and table.concat(value, ", ") or (#value .. " folders") end
    say(("%-17s %s"):format(key, tostring(value == nil and "-" or value)))
  end
  for _, problem in ipairs(info.problems) do
    say("PROBLEM           " .. problem)
  end
end

function commands.doctor(_, flags)
  local health = require("odoo.health")
  local checks = health.checks()
  local worst = health.worst(checks)
  if flags.json then
    say(vim.json.encode({ status = worst, checks = checks }))
  else
    local label = { ok = "ok   ", warn = "WARN ", error = "ERROR" }
    for _, check in ipairs(checks) do
      say(("%s %-13s %s"):format(label[check.status], check.name, check.message))
      if check.hint and check.status ~= "ok" then say("                    → " .. check.hint) end
    end
    say("RESULT: " .. worst)
  end
  os.exit(worst == "error" and 1 or 0)
end

function commands.setup(_, flags)
  local detect = require("odoo.detect")
  local workspace = need(flags.workspace or vim.fs.root(vim.fn.getcwd(), ".git"), "setup needs --workspace DIR", 2)
  local opts = {
    workspace = workspace,
    compose_dir = flags["compose-dir"],
    service = flags.service,
    db_service = flags["db-service"],
    own = flags.own,
    core = flags.core,
    python = flags.python,
  }
  local detected, problem
  if flags.print then
    detected, problem = detect.detect(opts)
  else
    detected, problem = detect.write(opts, settings.local_file, flags.force)
  end
  detected = need(detected, problem or "setup failed")
  if flags.print then say(table.concat(detect.render(detected), "\n")) end
  for _, note in ipairs(detected.notes) do
    io.stderr:write("CHECK: ", note, "\n")
  end
  if not flags.print then
    say("RESULT: ok wrote " .. settings.local_file .. " (restart nvim; verify with: odoo-nvim doctor)")
  end
end

function commands.brief(_, flags)
  require_settings()
  local agent = require("odoo.agent")
  if not flags.write then return say(table.concat(agent.brief(), "\n")) end
  local file, action = agent.write()
  say(("RESULT: ok brief %s in %s"):format(action, file))
end

function commands.frontend(args, flags)
  require_settings()
  local frontend = require("odoo.frontend")
  local modules = frontend.own_modules()
  local names = {}
  if args[1] then
    need(modules[args[1]], "no addon '" .. args[1] .. "' in your own folders (see: odoo-nvim info)")
    names = { args[1] }
  else
    names = vim.tbl_keys(modules)
    table.sort(names)
  end
  local problems, errors, warnings = {}, 0, 0
  for _, name in ipairs(names) do
    for _, problem in ipairs(frontend.check(modules[name])) do
      problem.module = name
      table.insert(problems, problem)
      if problem.severity == "error" then
        errors = errors + 1
      else
        warnings = warnings + 1
      end
    end
  end
  if flags.json then
    say(vim.json.encode({ ok = errors == 0, errors = errors, warnings = warnings, problems = problems }))
  else
    for _, p in ipairs(problems) do
      say(("%s:%d  %s: %s"):format(p.file, p.line, p.severity == "error" and "ERROR" or "warn", p.text))
    end
    local target = args[1] or (#names .. " addon(s)")
    say(
      ("RESULT: %s frontend %s (%d error(s), %d warning(s))"):format(
        errors == 0 and "ok" or "failed",
        target,
        errors,
        warnings
      )
    )
  end
  os.exit(errors == 0 and 0 or 1)
end

function commands.help() say(USAGE) end

local positional, flags = parse(arg)
local name = table.remove(positional, 1)
if not name or flags.help then
  say(USAGE)
  os.exit(name and 0 or 2)
end
local command = need(commands[name], "unknown command '" .. name .. "' (see: odoo-nvim help)", 2)
if flags.db then compose.state.db = flags.db end
command(positional, flags)
