local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- docker module with the compose `command:` replaced by `command`.
local function docker_with(command, overrides)
  H.project(overrides)
  local docker = require("odoo.docker")
  ---@diagnostic disable-next-line: duplicate-set-field
  docker.service_config = function() return { command = command } end
  return docker
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

return T
