local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

-- Each case changes PATH and MASON: put them back so the fake programs do not leak into other tests.
local saved = {}
local T = MiniTest.new_set({
  hooks = {
    pre_case = function() saved = { PATH = vim.env.PATH, MASON = vim.env.MASON } end,
    post_case = function()
      vim.env.PATH = saved.PATH
      vim.env.MASON = saved.MASON
    end,
  },
})

--- The check called `name`.
local function find(checks, name)
  for _, check in ipairs(checks) do
    if check.name == name then return check end
  end
end

--- A program that prints nothing and exits with `code`, in a new folder.
---@param dir string
---@param name string
---@param code integer
local function fake_program(dir, name, code)
  H.write(dir .. "/" .. name, { "#!/bin/sh", "exit " .. code })
  vim.fn.setfperm(dir .. "/" .. name, "rwxr-xr-x")
end

T["a tree-sitter that does not run is an error"] = function()
  H.project()
  local bin = H.tmpdir()
  fake_program(bin, "tree-sitter", 1)
  vim.env.MASON = H.tmpdir() -- an empty Mason folder: not the real one of this machine
  vim.env.PATH = bin .. ":" .. vim.env.PATH -- first on PATH, like the fake docker
  local check = find(require("odoo.health").checks(), "tree-sitter")
  eq(check.status, "error")
  eq(check.message, "found at " .. bin .. "/tree-sitter but it does not run")
  eq(check.hint, "reinstall it")
end

T["a tree-sitter in Mason's bin folder is found even when it is not on PATH"] = function()
  H.project()
  local mason = H.tmpdir() .. "/mason"
  fake_program(mason .. "/bin", "tree-sitter", 0)
  vim.env.MASON = mason
  vim.env.PATH = H.tmpdir() -- an empty folder: no tree-sitter anywhere on the PATH
  local check = find(require("odoo.health").checks(), "tree-sitter")
  eq(check.status, "ok")
  eq(check.message, mason .. "/bin/tree-sitter")
end

T["a broken tree-sitter on the PATH does not hide the working one from Mason"] = function()
  H.project()
  local mason = H.tmpdir() .. "/mason"
  fake_program(mason .. "/bin", "tree-sitter", 0)
  local shim = H.tmpdir()
  fake_program(shim, "tree-sitter", 1)
  vim.env.MASON = mason
  vim.env.PATH = shim .. ":" .. vim.env.PATH
  local check = find(require("odoo.health").checks(), "tree-sitter")
  eq(check.status, "ok")
  eq(check.message, mason .. "/bin/tree-sitter")
end

T["the checks have no node or npm (the CLI comes from Mason)"] = function()
  H.project()
  for _, check in ipairs(require("odoo.health").checks()) do
    eq(vim.tbl_contains({ "node", "npm" }, check.name), false)
  end
end

return T
