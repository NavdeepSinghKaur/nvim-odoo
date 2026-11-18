local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- compose module with the compose `command:` replaced by `command`.
local function docker_with(command, overrides)
  H.project(overrides)
  local compose = require("odoo.compose")
  ---@diagnostic disable-next-line: duplicate-set-field
  compose.service_config = function() return { command = command } end
  return compose
end

T["database comes from the compose command"] = function()
  eq(docker_with({ "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "mydb" }).db(), "mydb")
  eq(docker_with({ "odoo", "--database", "other" }).db(), "other")
  eq(docker_with({ "odoo", "--database=third" }).db(), "third")
  eq(docker_with({ "odoo", "-dfourth" }).db(), "fourth")
  eq(docker_with({ "odoo" }).db(), "odoo")
  eq(docker_with(nil).db(), "odoo")
end

T["settings.db and the runtime choice win over the compose command"] = function()
  local docker = docker_with({ "odoo", "-d", "mydb" }, { db = "from_settings" })
  eq(docker.db(), "from_settings")
  docker.state.db = "picked"
  eq(docker.db(), "picked")
end

T["debug override wraps the compose command in debugpy"] = function()
  local docker = docker_with({ "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "mydb" })
  local lines = vim.fn.readfile(docker.debug_override_file())
  eq(lines[2], "services:")
  eq(lines[3], "  odoo:")
  eq(
    lines[4],
    '    command: ["python3","-m","debugpy","--listen","0.0.0.0:5678","/usr/bin/odoo",'
      .. '"-c","/etc/odoo/odoo.conf","-d","mydb","--dev=xml"]'
  )
end

T["debug override does not wrap a compose command that already runs debugpy"] = function()
  local compose_command = {
    "python3",
    "-Xfrozen_modules=off",
    "-m",
    "debugpy",
    "--listen",
    "0.0.0.0:5678",
    "/usr/bin/odoo",
    "-c",
    "/etc/odoo/odoo.conf",
    "-d",
    "mydb",
    "-u",
    "nog_stock",
    "--dev=xml,css",
  } -- stylua: ignore
  local docker = docker_with(compose_command)
  local lines = vim.fn.readfile(docker.debug_override_file())
  eq(
    lines[4],
    '    command: ["python3","-Xfrozen_modules=off","-m","debugpy","--listen","0.0.0.0:5678","/usr/bin/odoo",'
      .. '"-c","/etc/odoo/odoo.conf","-d","mydb","-u","nog_stock","--dev=xml,css","--dev=xml"]'
  )
end

T["debug override finds an odoo-bin launched by python"] = function()
  local docker = docker_with({ "python3", "/opt/odoo/odoo-bin", "-d", "x" }, { odoo_bin = "/opt/odoo/odoo-bin" })
  eq(
    vim.fn.readfile(docker.debug_override_file())[4],
    '    command: ["python3","-m","debugpy","--listen","0.0.0.0:5678","/opt/odoo/odoo-bin","-d","x","--dev=xml"]'
  )
end

T["one-off commands run next to the live server on other ports"] = function()
  local compose = docker_with({ "odoo", "-d", "mydb" })
  local prefix = { "docker", "compose", "exec", "-T", "odoo", "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "mydb" }
  local ports = { "--http-port=8071", "--gevent-port=8073" }
  local function oneoff(args) return vim.list_extend(vim.list_extend(vim.deepcopy(prefix), args), ports) end
  eq(compose.argv.update("my_mod"), oneoff({ "-u", "my_mod", "--stop-after-init" }))
  eq(compose.argv.install("my_mod"), oneoff({ "-i", "my_mod", "--stop-after-init" }))
  eq(
    compose.argv.test("my_mod", "/my_mod:TestThing"),
    oneoff({
      "-u",
      "my_mod",
      "--test-enable",
      "--test-tags",
      "/my_mod:TestThing",
      "--log-level=test",
      "--stop-after-init",
    })
  )
  eq(compose.argv.test("my_mod")[15], "/my_mod")
end

T["service commands"] = function()
  local compose = docker_with({ "odoo", "-d", "mydb" })
  eq(compose.argv.restart(), { "docker", "compose", "restart", "odoo" })
  eq(compose.argv.logs(), { "docker", "compose", "logs", "--tail=300", "-f", "odoo" })
  eq(compose.argv.logs({ tail = 50, follow = false }), { "docker", "compose", "logs", "--tail=50", "odoo" })
  eq(compose.argv.psql(), { "docker", "compose", "exec", "db", "psql", "-U", "odoo", "-d", "mydb" })
  eq(compose.argv.debugpy_probe()[3], "odoo_web")
end

return T
