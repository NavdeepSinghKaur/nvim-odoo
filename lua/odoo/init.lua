-- ============================================================================
--  Odoo integration. Everything is under <Space>o (press <Space>o and wait) and :Odoo <Tab>
--
--  Files:  settings.lua + local.lua (YOUR paths/db/container, :Odoo config)
--          paths.lua (module & path helpers)    odools.lua (language server config)
--          docker.lua (update/test/debug...)    pickers.lua (find model / xml id...)
--          log.lua (output panel + tracebacks -> quickfix)
-- ============================================================================
local S = require("odoo.settings")
local P = require("odoo.paths")
local M = {}

M.settings = S
M.is_readonly_path = P.is_readonly
M.is_odoo_file = P.is_odoo

local function docker() return require("odoo.docker") end
local function pickers() return require("odoo.pickers") end

--- Run fn(module) with the module of the current file, or ask which one.
local function with_module(fn, title)
  local name = P.module_of()
  if name then return fn(name) end
  pickers().pick_module(title or "Which module?", fn)
end

-- ------------------------------------------------------------------ tests
--- Test tag for the cursor position: /module:TestClass.test_method (or just the class / module)
function M.test_tag_at_cursor()
  local module = P.module_of()
  if not module then return nil end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
  local method, class
  for i = #lines, 1, -1 do
    local l = lines[i]
    if not method and not class then method = l:match("^%s+def (test_[%w_]+)") end
    class = l:match("^class ([%w_]+)")
    if class then break end
    if not method and l:match("^%s+def ") then method = false end -- inside a non-test method
  end
  if not class then return "/" .. module, module end
  return "/" .. module .. ":" .. class .. (method and ("." .. method) or ""), module
end

function M.test_at_cursor()
  local tag, module = M.test_tag_at_cursor()
  if not tag then
    vim.notify("Open a test file inside a module first", vim.log.levels.WARN)
    return
  end
  docker().test(module, tag)
end

-- ------------------------------------------------------------------ debugger
function M.dap_config()
  local mappings = {}
  for _, m in ipairs(P.mappings()) do
    table.insert(mappings, { localRoot = m["local"], remoteRoot = m.remote })
  end
  return {
    type = "python",
    request = "attach",
    name = "Odoo (Docker, debugpy :" .. S.debug.port .. ")",
    connect = { host = S.debug.host, port = S.debug.port },
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
  local _, dir = P.module_of()
  if dir then
    vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/__manifest__.py"))
  else
    pickers().modules()
  end
end

function M.browser(debug_mode) vim.ui.open(S.web_url .. "/web" .. (debug_mode and "?debug=1" or "")) end

function M.info()
  local st = docker().status()
  local name, dir = P.module_of()
  local lines = {
    "Container   "
      .. docker().container()
      .. ": "
      .. (not st.exists and "not created" or st.running and "running" or "stopped")
      .. (st.debug and "  🐞 DEBUG MODE (debugpy :" .. S.debug.port .. ")" or ""),
    "Database    " .. docker().db() .. "   (change: :Odoo db)",
    "Module      " .. (name and (name .. "  " .. dir) or "-"),
    "Core copy   " .. S.core .. (vim.fn.isdirectory(S.core) == 1 and "" or "  (MISSING → :Odoo sync-core)"),
    "Web         " .. S.web_url,
    "Workspace   " .. S.workspace,
    "Compose     " .. S.compose_dir .. (docker().compose_file() and "" or "  (NO compose file here)"),
    "Settings    " .. (S.configured and S.local_file or "defaults only → :Odoo config"),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Odoo" })
end

--- Copy the Odoo core source out of Docker (after `docker compose build` / an image update).
--- Source: settings.core_image, else the odoo container, else the image of the service.
function M.sync_core()
  local st = docker().status()
  local image = S.core_image or (not st.exists and docker().service_config().image) or nil
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
      S.core,
      S.core_remote,
      image or "",
      image and "" or docker().container(),
    },
    quickfix = false,
    on_exit = function(code)
      if code == 0 then vim.cmd("silent! OdooLs restart") end
    end,
  })
end

--- Open lua/odoo/local.lua (your paths / docker names), created from the example the first time.
function M.config()
  if not vim.uv.fs_stat(S.local_file) then
    vim.fn.writefile(vim.fn.readfile(S.example_file), S.local_file)
    vim.notify("Created " .. S.local_file .. "\nSet your paths, save, restart nvim, then check with :Odoo info")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(S.local_file))
end

--- Statusline: running Odoo jobs
function M.statusline()
  local running = require("odoo.log").running()
  if #running == 0 then return "" end
  return "󰑮 " .. table.concat(running, ", ")
end

-- ------------------------------------------------------------------ :Odoo command
M.commands = {
  update = {
    function(a)
      if a then
        docker().update(a, true)
      else
        with_module(function(m) docker().update(m, true) end)
      end
    end,
    "Update module (-u) + restart (Python & XML changes)",
  },
  ["update-xml"] = {
    function(a)
      if a then
        docker().update(a, false)
      else
        with_module(function(m) docker().update(m, false) end)
      end
    end,
    "Update module without restart (XML/data only, faster)",
  },
  install = {
    function(a)
      if a then
        docker().install(a)
      else
        pickers().pick_module("Install which module?", docker().install)
      end
    end,
    "Install a module",
  },
  test = {
    function(a)
      if a then
        docker().test(a)
      else
        with_module(function(m) docker().test(m) end)
      end
    end,
    "Run the tests of the module",
  },
  ["test-cursor"] = { M.test_at_cursor, "Run the test class/method under the cursor" },
  restart = { function() docker().restart() end, "Restart the Odoo server" },
  start = { function() docker().up() end, "Start Odoo in NORMAL mode (leaves debug mode)" },
  stop = { function() docker().stop() end, "Stop the Odoo container" },
  debug = { M.debug, "Start debug mode (debugpy) + attach the debugger" },
  attach = { M.attach, "Attach debugger (Odoo already in debug mode)" },
  logs = { function() docker().logs() end, "Follow the Odoo log" },
  qf = { function() require("odoo.log").qf_from_current() end, "Tracebacks of the log panel → quickfix" },
  shell = { function() docker().shell() end, "Odoo shell (python with env) on the DB" },
  psql = { function() docker().psql() end, "psql on the DB" },
  bash = { function() docker().bash() end, "bash inside the Odoo container" },
  db = { function() docker().pick_db() end, "Choose the database for these commands" },
  models = { function() pickers().models() end, "Find a model (definition + every _inherit)" },
  xmlids = { function() pickers().xmlids() end, "Find an XML id" },
  views = { function(a) pickers().views(a) end, "Views/actions/rules of a model" },
  modules = { function() pickers().modules() end, "Find a module" },
  manifest = { M.open_manifest, "Open __manifest__.py of current module" },
  browser = { function() M.browser(true) end, "Open Odoo in the browser (?debug=1)" },
  info = { M.info, "Container / DB / module status" },
  ["sync-core"] = { M.sync_core, "Re-copy Odoo core source from the Docker image" },
  config = { M.config, "Edit YOUR settings: paths, docker service, db (lua/odoo/local.lua)" },
}

-- odoo_ls can't watch files on Linux, so a `git checkout` / `git pull` made in lazygit or another
-- terminal is not seen. We check the commit of the workspace when nvim gets focus or a terminal
-- closes, and restart odoo_ls if it changed.
local last_head
local function check_git_head()
  vim.system({ "git", "-C", S.workspace, "rev-parse", "HEAD" }, { text = true }, function(r)
    if r.code ~= 0 then return end
    local head = vim.trim(r.stdout)
    vim.schedule(function()
      if last_head and head ~= last_head and #vim.lsp.get_clients({ name = "odoo_ls" }) > 0 then
        vim.notify("Git commit changed → restarting odoo_ls")
        vim.cmd("silent! OdooLs restart")
        pcall(function() require("odoo.pickers").clear_cache() end)
      end
      last_head = head
    end)
  end)
end

function M.setup()
  if not S.configured then
    vim.defer_fn(
      function() vim.notify("Odoo paths are not set yet → run  :Odoo config", vim.log.levels.WARN, { title = "Odoo" }) end,
      500
    )
  end
  check_git_head()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose" }, {
    group = vim.api.nvim_create_augroup("odoo_git_head", { clear = true }),
    callback = function() vim.defer_fn(check_git_head, 300) end,
  })

  vim.api.nvim_create_user_command("Odoo", function(o)
    local sub, arg = o.fargs[1], o.fargs[2]
    if not sub then
      local names = vim.tbl_keys(M.commands)
      table.sort(names)
      vim.ui.select(names, {
        prompt = "Odoo",
        format_item = function(n) return ("%-12s %s"):format(n, M.commands[n][2]) end,
      }, function(c)
        if c then M.commands[c][1]() end
      end)
      return
    end
    local c = M.commands[sub]
    if not c then return vim.notify("Unknown :Odoo " .. sub, vim.log.levels.ERROR) end
    c[1](arg)
  end, {
    nargs = "*",
    desc = "Odoo helpers",
    complete = function(lead, line)
      local n = #vim.split(line, "%s+")
      if n <= 2 then
        return vim.tbl_filter(function(k) return k:find(lead, 1, true) == 1 end, vim.tbl_keys(M.commands))
      end
      -- module names for update/install/test
      local mods = {}
      for _, d in ipairs(P.addon_dirs()) do
        for name, t in vim.fs.dir(d) do
          if t == "directory" and name:find(lead, 1, true) == 1 then table.insert(mods, name) end
        end
      end
      return mods
    end,
  })

  local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true }) end
  local cmd = function(name) return M.commands[name][1] end
  -- server
  map("<leader>ou", cmd("update"), "Update module + restart")
  map("<leader>oU", cmd("update-xml"), "Update module (XML only, no restart)")
  map("<leader>oi", cmd("install"), "Install module…")
  map("<leader>or", cmd("restart"), "Restart Odoo")
  map("<leader>oS", cmd("start"), "Start Odoo (normal mode)")
  map("<leader>oK", cmd("stop"), "Stop (kill) Odoo")
  map("<leader>ol", cmd("logs"), "Follow Odoo log")
  map("<leader>oq", cmd("qf"), "Log tracebacks → quickfix")
  -- tests
  map("<leader>ot", cmd("test"), "Test current module")
  map("<leader>oT", cmd("test-cursor"), "Test under cursor")
  -- debug
  map("<leader>od", cmd("debug"), "Debug Odoo (debugpy)")
  -- consoles
  map("<leader>os", cmd("shell"), "Odoo shell")
  map("<leader>op", cmd("psql"), "psql")
  map("<leader>ob", cmd("bash"), "Container bash")
  map("<leader>oD", cmd("db"), "Choose database")
  -- navigation
  map("<leader>om", function() pickers().models() end, "Find model")
  map("<leader>oM", function() pickers().model_at_cursor() end, "Find model under cursor")
  map("<leader>ox", function() pickers().xmlids() end, "Find XML id")
  map("<leader>oX", function() pickers().xmlid_at_cursor() end, "Find XML id under cursor")
  map("<leader>ov", function() pickers().views() end, "Views/actions of this model")
  map("<leader>oo", function() pickers().modules() end, "Find module")
  map("<leader>o.", M.open_manifest, "Open manifest")
  map("<leader>of", function() pickers().files_module() end, "Files in this module")
  map("<leader>og", function() pickers().grep_module() end, "Grep in this module")
  map("<leader>oc", function() pickers().files_core() end, "Files in Odoo core")
  map("<leader>oC", function() pickers().grep_core() end, "Grep in Odoo core")
  map("<leader>oa", function() pickers().grep_addons() end, "Grep in ALL addons")
  map("<leader>oA", function() pickers().files_addons() end, "Files in ALL addons")
  map("<leader>ow", function() pickers().grep_word_addons() end, "Word under cursor in ALL addons")
  map("<leader>oB", function() M.browser(true) end, "Open in browser (debug=1)")
  map("<leader>o?", M.info, "Odoo status")
  map("<leader>oO", "<Cmd>Odoo<CR>", "All Odoo commands…")
end

return M
