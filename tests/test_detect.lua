local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- A project on disk with a compose file answered by the fake docker.
local function project()
  local _, root = H.project()
  H.write(H.fake_docker() .. "/config.json", { H.compose_config(root) })
  return root
end

T["detects the settings from the compose file and odoo.conf"] = function()
  local root = project()
  local detected = assert(require("odoo.detect").detect({ workspace = root .. "/ws", core = root .. "/core" }))
  eq(detected.values, {
    workspace = root .. "/ws",
    compose_dir = root .. "/docker", -- found next to the workspace because it mounts it
    service = "web",
    db_service = "postgres",
    container = "project_web",
    db_user = "admin",
    core = root .. "/core",
    own_addons = { root .. "/ws/custom" },
    addons_paths = { root .. "/ws/custom", root .. "/ws/oca/web" },
    readonly_paths = { root .. "/core", root .. "/ws/oca/web" }, -- its own git repo: not your code
  })
  eq(#detected.notes, 1) -- only python was not given
end

T["--own decides what is yours"] = function()
  local root = project()
  local detect = require("odoo.detect")
  local detected =
    assert(detect.detect({ workspace = root .. "/ws", own = { root .. "/ws/oca/web" }, python = "/usr/bin/python3" }))
  eq(detected.values.own_addons, { root .. "/ws/oca/web" })
  eq(detected.values.readonly_paths[2], root .. "/ws/custom")
end

T["the written file loads as settings without problems"] = function()
  local root = project()
  local detect = require("odoo.detect")
  local file = root .. "/local.lua"
  assert(detect.write({ workspace = root .. "/ws", core = root .. "/core" }, file))
  eq(detect.write({ workspace = root .. "/ws" }, file), nil) -- never replaces without force
  H.reset()
  local settings = require("odoo.settings").load(dofile(file))
  eq(settings.problems, {})
  eq(settings.service, "web")
  eq(require("odoo.compose").db(), "projectdb")
  eq(require("odoo.paths").to_local("/mnt/oca/web/web_responsive/x.py"), root .. "/ws/oca/web/web_responsive/x.py")
end

T["says what is wrong when there is nothing to detect"] = function()
  local detect = require("odoo.detect")
  local detected, problem = detect.detect({ workspace = "/nowhere/at/all" })
  eq(detected, nil)
  eq(problem, "no such folder: /nowhere/at/all")
end

return T
