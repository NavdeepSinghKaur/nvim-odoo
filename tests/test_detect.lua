local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- A project on disk with a compose file answered by the fake docker.
local function project()
  local _, root = H.project()
  H.write(H.fake_docker() .. "/config.json", { H.compose_config(root) })
  return root
end

--- Like project(), with `change(service)` applied to the odoo service of the compose config.
local function project_with(change)
  local _, root = H.project()
  local config = vim.json.decode(H.compose_config(root))
  change(config.services.web)
  H.write(H.fake_docker() .. "/config.json", { vim.json.encode(config) })
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

T["detects a debugpy wrapped command with another odoo binary and debug port"] = function()
  local root = project_with(function(service)
    service.command = {
      "python3",
      "-Xfrozen_modules=off",
      "-m",
      "debugpy",
      "--listen",
      "0.0.0.0:5679",
      "/opt/odoo/odoo-bin",
      "-c",
      "/etc/odoo/odoo.conf",
      "-d",
      "projectdb",
    } -- stylua: ignore
    service.ports = { { target = 8069, published = "8069" }, { target = 5679, published = "5679" } }
  end)
  local detect = require("odoo.detect")
  local detected = assert(detect.detect({ workspace = root .. "/ws", core = root .. "/core" }))
  eq(detected.values.odoo_bin, "/opt/odoo/odoo-bin")
  eq(detected.values.debug, { port = 5679 })
  eq(#detected.notes, 1) -- only python was not given
  eq(vim.tbl_contains(detect.render(detected), "  debug = { port = 5679 },"), true)
  eq(vim.tbl_contains(detect.render(detected), '  odoo_bin = "/opt/odoo/odoo-bin",'), true)
end

T["notes a debug port that the compose file does not publish"] = function()
  local root = project_with(
    function(service)
      service.command = { "python3", "-m", "debugpy", "--listen=5680", "/usr/bin/odoo", "-c", "/etc/odoo/odoo.conf" }
    end
  )
  local detected = assert(
    require("odoo.detect").detect({ workspace = root .. "/ws", core = root .. "/core", python = "/usr/bin/python3" })
  )
  eq(detected.values.debug, { port = 5680 })
  eq(detected.values.odoo_bin, nil) -- the default
  eq(detected.notes, {
    'debug port 5680 is not published in the compose file: add "5680:5680" to the ports of the web service (F5 cannot attach)',
  })
end

T["takes web_url from the published port"] = function()
  local root = project_with(
    function(service) service.ports = { { target = 8069, published = "8070" }, { target = 5678, published = "5678" } } end
  )
  local detected = assert(require("odoo.detect").detect({ workspace = root .. "/ws", core = root .. "/core" }))
  eq(detected.values.web_url, "http://localhost:8070")
  eq(vim.tbl_contains(require("odoo.detect").render(detected), '  web_url = "http://localhost:8070",'), true)
end

T["uses the .venv python of the workspace"] = function()
  local root = project()
  H.write(root .. "/ws/.venv/bin/python", { "#!/bin/sh" })
  vim.fn.setfperm(root .. "/ws/.venv/bin/python", "rwxr-xr-x")
  local detected = assert(require("odoo.detect").detect({ workspace = root .. "/ws", core = root .. "/core" }))
  eq(detected.values.python, root .. "/ws/.venv/bin/python")
  eq(#detected.notes, 0)
end

return T
