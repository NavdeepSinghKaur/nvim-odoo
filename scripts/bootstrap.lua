-- Unattended first-time setup of everything the config downloads by itself: plugins at the
-- versions of lazy-lock.json, the Mason tools and the Treesitter parsers. In the editor these
-- install in the background on first start; this script waits for each step and reports it.
--
-- Usage (scripts/install.sh does this):  nvim --headless "+luafile scripts/bootstrap.lua"
-- Prints one "STEP <name>: ok|failed" line per step and exits with 1 if a step failed.
local tools = require("config.tools")

local MINUTE = 60 * 1000
local failed = false

---@param name string
---@param step fun(): string? returns a problem, or nil when it worked
local function run(name, step)
  local ok, problem = pcall(step)
  if not ok or problem then
    failed = true
    io.stdout:write(("\nSTEP %s: failed: %s\n"):format(name, tostring(problem)))
  else
    io.stdout:write(("\nSTEP %s: ok\n"):format(name))
  end
end

run("plugins", function()
  require("lazy").restore({ wait = true, show = false })
  local missing = {}
  for _, plugin in ipairs(require("lazy").plugins()) do
    if not vim.uv.fs_stat(plugin.dir) then table.insert(missing, plugin.name) end
  end
  if #missing > 0 then return "not installed: " .. table.concat(missing, ", ") end
end)

run("mason tools", function()
  -- both load on an event that never fires without a UI
  require("lazy").load({ plugins = { "mason.nvim", "mason-tool-installer.nvim" } })
  require("mason-tool-installer").check_install(false, true) -- sync: returns when all are done
  local registry = require("mason-registry")
  local missing = vim.tbl_filter(function(name) return not registry.is_installed(name) end, tools.mason)
  if #missing > 0 then return "not installed: " .. table.concat(missing, ", ") end
end)

run("treesitter parsers", function()
  if vim.fn.executable("tree-sitter") == 0 then return "the tree-sitter CLI is not on PATH" end
  local treesitter = require("nvim-treesitter")
  treesitter.install(tools.parsers):wait(10 * MINUTE)
  local installed = treesitter.get_installed()
  local missing = vim.tbl_filter(function(parser) return not vim.tbl_contains(installed, parser) end, tools.parsers)
  if #missing > 0 then return "not installed: " .. table.concat(missing, ", ") end
end)

vim.cmd(failed and "cquit 1" or "quitall")
