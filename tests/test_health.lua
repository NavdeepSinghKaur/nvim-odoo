local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- The check called `name`.
local function find(checks, name)
  for _, check in ipairs(checks) do
    if check.name == name then return check end
  end
end

T["a tree-sitter that does not run is an error"] = function()
  H.project()
  local bin = H.tmpdir()
  H.write(bin .. "/tree-sitter", { "#!/bin/sh", "exit 1" })
  vim.fn.setfperm(bin .. "/tree-sitter", "rwxr-xr-x")
  vim.env.PATH = bin .. ":" .. vim.env.PATH -- first on PATH, like the fake docker
  local check = find(require("odoo.health").checks(), "tree-sitter")
  eq(check.status, "error")
  eq(check.message, "found at " .. bin .. "/tree-sitter but it does not run")
  eq(check.hint, "reinstall it")
end

return T
