-- ============================================================================
--  Odoo integration. Everything is under <Space>o (press <Space>o and wait) and :Odoo <Tab>
--
--  Files:  settings.lua + local.lua (YOUR paths/db/container, :Odoo config)
--          commands.lua (the :Odoo sub-commands and their keys)
--          paths.lua (module & path helpers)    odools.lua (language server config)
--          compose.lua (what to run)            docker.lua (runs it in the log panel)
--          tests.lua (test under cursor)        traceback.lua (tracebacks -> quickfix)
--          pickers.lua (find model / xml id...) log.lua (output panel)
--          git_watch.lua (restart odoo_ls after a checkout)
-- ============================================================================
local settings = require("odoo.settings")
local paths = require("odoo.paths")
local M = {}

M.settings = settings
M.is_readonly_path = paths.is_readonly
M.is_odoo_file = paths.is_odoo

local function docker() return require("odoo.docker") end
local function pickers() return require("odoo.pickers") end

-- ------------------------------------------------------------------ tests
--- Test tag for the cursor position: /module:TestClass.test_method (or just the class / module)
---@return string? tag, string? module
function M.test_tag_at_cursor() return require("odoo.tests").tag_at_cursor() end

function M.test_at_cursor()
  local tag, module = M.test_tag_at_cursor()
  if not tag or not module then
    vim.notify("Open a test file inside a module first", vim.log.levels.WARN)
    return
  end
  docker().test(module, tag)
end

-- ------------------------------------------------------------------ debugger
function M.dap_config()
  local mappings = {}
  for _, m in ipairs(paths.mappings()) do
    table.insert(mappings, { localRoot = m["local"], remoteRoot = m.remote })
  end
  return {
    type = "python",
    request = "attach",
    name = "Odoo (Docker, debugpy :" .. settings.debug.port .. ")",
    connect = { host = settings.debug.host, port = settings.debug.port },
    pathMappings = mappings,
    justMyCode = false, -- lets you step into Odoo core (the local copy, settings.core)
    subProcess = false,
  }
end

function M.attach() require("dap").run(M.dap_config()) end

--- F5 when not debugging: make sure Odoo runs under debugpy, then attach.
function M.debug()
  local st = docker().status()
  if st.running and st.debug then return M.attach() end
  local start = function()
    docker().debug_up(function() M.attach() end)
  end
  if not st.running then return start() end
  vim.ui.select({ "Yes, restart in debug mode", "No" }, {
    prompt = "Odoo runs in normal mode. Restart it under the debugger? (stays in debug mode until :Odoo start)",
  }, function(choice)
    if choice and choice:match("^Yes") then start() end
  end)
end

-- ------------------------------------------------------------------ misc
function M.cheatsheet()
  Snacks.win({
    file = vim.fn.stdpath("config") .. "/CHEATSHEET.md",
    width = 0.85,
    height = 0.9,
    border = "rounded",
    title = " Cheat sheet  (q to close, / to search) ",
    bo = { modifiable = false, filetype = "markdown" },
    wo = { wrap = true, linebreak = true, conceallevel = 2, spell = false },
    keys = { q = "close" },
  })
end

function M.open_manifest()
  local _, dir = paths.module_of()
  if dir then
    vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/__manifest__.py"))
  else
    pickers().modules()
  end
end

function M.browser(debug_mode) vim.ui.open(settings.web_url .. "/web" .. (debug_mode and "?debug=1" or "")) end

function M.info()
  local st = docker().status()
  local name, dir = paths.module_of()
  local lines = {
    "Container   "
      .. (docker().container() or settings.service)
      .. ": "
      .. (not st.exists and "not created" or st.running and "running" or "stopped")
      .. (st.debug and "  🐞 DEBUG MODE (debugpy :" .. settings.debug.port .. ")" or ""),
    "Database    " .. docker().db() .. "   (change: :Odoo db)",
    "Module      " .. (name and (name .. "  " .. dir) or "-"),
    "Core copy   "
      .. settings.core
      .. (vim.fn.isdirectory(settings.core) == 1 and "" or "  (MISSING → :Odoo sync-core)"),
    "Web         " .. settings.web_url,
    "Workspace   " .. settings.workspace,
    "Compose     " .. settings.compose_dir .. (docker().compose_file() and "" or "  (NO compose file here)"),
    "Settings    " .. (settings.configured and settings.local_file or "defaults only → :Odoo config"),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Odoo" })
end

--- Copy the Odoo core source out of Docker (after `docker compose build` / an image update).
--- Source: settings.core_image, else the odoo container, else the image of the service.
function M.sync_core()
  local st = docker().status()
  local image = settings.core_image or (not st.exists and docker().service_config().image) or nil
  if not image and not st.exists then
    vim.notify(
      "No container yet and no image known: run :Odoo start first, or set core_image (:Odoo config)",
      vim.log.levels.ERROR
    )
    return
  end
  local script = [[set -e
core="$1"; remote="$2"; image="$3"; cid="$4"
if [ -n "$image" ]; then
  cid=$(docker create "$image")
  trap 'docker rm -f $cid >/dev/null' EXIT
fi
rm -rf "$core.new" && mkdir -p "$core.new"
docker cp -q "$cid:$remote" "$core.new/odoo"
find "$core.new" -name __pycache__ -type d -prune -exec rm -rf {} +
rm -rf "$core" && mv "$core.new" "$core"
echo "Odoo core copied to $core"]]
  require("odoo.log").run({
    title = "sync-core",
    cmd = {
      "bash",
      "-c",
      script,
      "sync-core",
      settings.core,
      settings.core_remote,
      image or "",
      image and "" or docker().container() or "",
    },
    quickfix = false,
    on_exit = function(code)
      if code ~= 0 then return end
      vim.cmd("silent! OdooLs restart")
      pickers().clear_cache()
    end,
  })
end

--- Open lua/odoo/local.lua (your paths / docker names), created from the example the first time.
function M.config()
  if not vim.uv.fs_stat(settings.local_file) then
    vim.fn.writefile(vim.fn.readfile(settings.example_file), settings.local_file)
    vim.notify("Created " .. settings.local_file .. "\nSet your paths, save, restart nvim, then check with :Odoo info")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(settings.local_file))
end

--- Statusline: running Odoo jobs
function M.statusline()
  local running = require("odoo.log").running()
  if #running == 0 then return "" end
  return "󰑮 " .. table.concat(running, ", ")
end

--- Tell the user, once the UI is up, what is missing or wrong in their settings.
local function report_settings()
  local message
  if not settings.configured then
    message = "Odoo paths are not set yet → run  :Odoo config"
  elseif #settings.problems > 0 then
    message = "Problems in lua/odoo/local.lua (:Odoo config):\n• " .. table.concat(settings.problems, "\n• ")
  end
  if message then vim.defer_fn(function() vim.notify(message, vim.log.levels.WARN, { title = "Odoo" }) end, 500) end
end

function M.setup()
  report_settings()
  require("odoo.git_watch").setup()
  require("odoo.commands").setup()
end

return M
