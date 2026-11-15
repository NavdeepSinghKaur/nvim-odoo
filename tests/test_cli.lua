local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local TEST_LOG = {
  "2026-01-01 10:00:00,000 1 INFO projectdb odoo.modules.loading: loading my_mod",
  "2026-01-01 10:00:01,000 1 ERROR projectdb odoo.addons.my_mod.tests.test_thing: FAIL: TestThing.test_create",
  "Traceback (most recent call last):",
  '  File "/mnt/custom/my_mod/models/thing.py", line 1, in test_create',
  "    self.assertTrue(False)",
  "AssertionError: False is not true",
  "2026-01-01 10:00:02,000 1 ERROR projectdb odoo.tests.result: 1 failed, 0 error(s) of 3 tests when loading database 'projectdb'",
}

--- A configured project whose docker is the fake one. Returns its root and the fake's folder.
local function project()
  local _, root = H.project()
  local fake = H.fake_docker()
  H.write(fake .. "/config.json", { H.compose_config(root) })
  H.write(fake .. "/test.log", TEST_LOG)
  H.write(fake .. "/update.log", { "2026-01-01 10:00:00,000 1 INFO projectdb odoo.modules.loading: Modules loaded." })
  assert(require("odoo.detect").write({ workspace = root .. "/ws", core = root .. "/core" }, root .. "/local.lua"))
  vim.env.ODOO_NVIM_SETTINGS = root .. "/local.lua"
  return root, fake
end

--- Run scripts/odoo-nvim: exit code, stdout, stderr.
local function cli(...)
  local result = vim.system({ "scripts/odoo-nvim", ... }, { text = true }):wait()
  return result.code, result.stdout, result.stderr
end

local function has(text, part) eq({ part, text:find(part, 1, true) ~= nil }, { part, true }) end

T["test: failing tests give exit 1, local paths and a result line"] = function()
  local root = project()
  vim.env.FAKE_DOCKER_EXIT = "1"
  local code, stdout = cli("test", "my_mod")
  eq(code, 1)
  has(stdout, 'File "' .. root .. '/ws/custom/my_mod/models/thing.py", line 1')
  has(stdout, "Problem locations (your code first):\n  " .. root .. "/ws/custom/my_mod/models/thing.py:1")
  has(stdout, "RESULT: failed test /my_mod (1 failed, 0 error(s) of 3 tests")

  local _, last = cli("last")
  has(last, "--test-tags /my_mod")
  has(last, root .. "/ws/custom/my_mod/models/thing.py")
  has(last, "[exit code 1]")
end

T["test --json: one object an agent can read"] = function()
  local root = project()
  local code, stdout = cli("test", "/my_mod:TestThing.test_create", "--json")
  eq(code, 1) -- the log says a test failed even though odoo exited with 0
  local report = vim.json.decode(stdout)
  eq(report.ok, false)
  eq(report.target, "/my_mod:TestThing.test_create")
  eq(
    report.problems[1],
    { file = root .. "/ws/custom/my_mod/models/thing.py", line = 1, text = report.problems[1].text }
  )
  eq(report.log_errors, 2)
end

T["update: restarts the server and reports ok"] = function()
  project()
  local code, stdout = cli("update", "my_mod")
  eq(code, 0)
  has(stdout, "Modules loaded.")
  has(stdout, "Container web  Restarted")
  has(stdout, "RESULT: ok update my_mod")
  code, stdout = cli("update", "my_mod", "--no-restart")
  eq({ code, stdout:find("Restarted", 1, true) }, { 0, nil })
end

T["info --json and usage errors"] = function()
  local root = project()
  local _, stdout = cli("info", "--json")
  local info = vim.json.decode(stdout)
  eq({ info.container, info.database, info.container_status }, { "project_web", "projectdb", "running" })
  eq(info.own_addons, { root .. "/ws/custom" })
  eq((cli("nonsense")), 2)
  eq((cli("test")), 2)
end

T["without settings it says how to get them"] = function()
  vim.env.ODOO_NVIM_SETTINGS = "/nowhere/local.lua"
  local code, _, stderr = cli("update", "my_mod")
  eq(code, 1)
  has(stderr, "odoo-nvim setup --workspace")
end

return T
