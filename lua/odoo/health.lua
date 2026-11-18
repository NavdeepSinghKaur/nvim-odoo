-- Is everything in place? `:checkhealth odoo` in the editor, `odoo-nvim doctor [--json]` in a
-- terminal. checks() only collects facts, so both can present them their own way.
local settings = require("odoo.settings")
local compose = require("odoo.compose")
local M = {}

---@class OdooHealthCheck
---@field name string
---@field status "ok"|"warn"|"error"
---@field message string
---@field hint? string what to do about it

---@param name string
---@return boolean
local function has(name) return vim.fn.executable(name) == 1 end

--- First line a command prints (nil when it cannot run).
---@param cmd string[]
---@return string?
local function first_line(cmd)
  local ran, result = pcall(function() return vim.system(cmd, { text = true }):wait() end)
  if not ran or result.code ~= 0 then return nil end
  return vim.split(vim.trim(result.stdout .. result.stderr), "\n")[1]
end

--- Full path of the first of `names` that is on the PATH (nil when none is).
---@param names string[]
---@return string?
local function program_path(names)
  local found = vim.tbl_filter(has, names)[1]
  if found then return vim.fn.exepath(found) end
end

--- Full path of the tree-sitter CLI. Mason installs it into its bin folder, which only the editor
--- puts on the PATH: `odoo-nvim doctor` runs without the editor, so look there too.
---@return string?
local function tree_sitter_path()
  -- Mason's copy first: inside the editor it is first on the PATH too, so a broken Windows shim
  -- on the WSL PATH (/mnt/c) must not hide it.
  local mason = (vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")) .. "/bin/tree-sitter"
  if vim.fn.executable(mason) == 1 then return mason end
  return program_path({ "tree-sitter" })
end

---@return string version pinned in scripts/odoo-ls.version
local function pinned_odoo_ls()
  local file = settings.config_dir .. "/scripts/odoo-ls.version"
  return vim.fn.filereadable(file) == 1 and vim.trim(vim.fn.readfile(file)[1] or "") or ""
end

---@return OdooHealthCheck[]
function M.checks()
  local checks = {}
  ---@param name string
  ---@param status "ok"|"warn"|"error"
  ---@param message string
  ---@param hint? string
  local function add(name, status, message, hint)
    table.insert(checks, { name = name, status = status, message = message, hint = hint })
  end

  -- programs
  local version = vim.version()
  local version_text = ("%d.%d.%d"):format(version.major, version.minor, version.patch)
  if vim.fn.has("nvim-0.12") == 1 then
    add("neovim", "ok", version_text)
  else
    add("neovim", "error", version_text, "Neovim 0.12 or newer is needed")
  end
  local required = {
    { "git" },
    { "rg", hint = "install ripgrep (pickers and grep)" },
    { "fd", "fdfind", hint = "install fd (file pickers)" },
    { "tree-sitter", hint = "installed by Mason on first start (:Mason), or install the tree-sitter CLI" },
    { "python3", hint = "install Python 3 (runs the odoo-ls proxy)" },
    { "cc", "gcc", "clang", hint = "install a C compiler (Treesitter parsers)" },
    { "curl" },
    { "unzip" },
    { "tar" },
    { "gzip" },
  }
  -- Under WSL the Windows shims on the PATH (/mnt/c/...) are found but crash when run.
  local must_run = { ["tree-sitter"] = true }
  for _, program in ipairs(required) do
    local path
    if program[1] == "tree-sitter" then
      path = tree_sitter_path()
    else
      path = program_path(program)
    end
    -- run the full path: it may not be on the PATH (see tree_sitter_path)
    if path and must_run[program[1]] and (not first_line({ path, "--version" }) or vim.startswith(path, "/mnt/")) then
      local windows = vim.startswith(path, "/mnt/")
      local hint = windows and "a Windows program on the WSL PATH? install the Linux one" or "reinstall it"
      add(program[1], "error", "found at " .. path .. " but it does not run", hint)
    elseif path then
      add(program[1], "ok", path)
    else
      add(program[1], "error", "not found", program.hint or ("install " .. program[1]))
    end
  end
  if first_line({ "python3", "-m", "venv", "--help" }) then
    add("python3 venv", "ok", "python3 -m venv works")
  else
    add(
      "python3 venv",
      "error",
      "python3 -m venv does not work",
      "install python3-venv (Mason needs it for black and debugpy)"
    )
  end
  local clipboard = vim.tbl_filter(has, { "wl-copy", "xclip", "xsel", "pbcopy", "win32yank.exe", "clip.exe" })[1]
  if clipboard then
    add("clipboard", "ok", clipboard)
  else
    add(
      "clipboard",
      "warn",
      "no clipboard tool found",
      "install wl-clipboard or xclip (yank/paste with the system clipboard)"
    )
  end
  local optional = {
    { "make", "only for `make check`" },
    { "lazygit", "git UI on <Space>gg" },
    { "claude", "Claude Code panel on <Space>a" },
  }
  for _, program in ipairs(optional) do
    local name, purpose = program[1], program[2]
    if has(name) then
      add(name, "ok", vim.fn.exepath(name))
    else
      add(name, "warn", "not found (optional)", purpose)
    end
  end

  -- language server
  local pinned = pinned_odoo_ls()
  local odoo_ls = first_line({ settings.odoo_ls_cmd, "--version" })
  if not odoo_ls then
    add("odoo-ls", "error", settings.odoo_ls_cmd .. " not found", "run scripts/install-odoo-ls.sh")
  elseif pinned ~= "" and not odoo_ls:find(pinned, 1, true) then
    add(
      "odoo-ls",
      "warn",
      odoo_ls .. " (this config is tested with " .. pinned .. ")",
      "run scripts/install-odoo-ls.sh"
    )
  else
    add("odoo-ls", "ok", odoo_ls)
  end

  -- settings
  if not settings.configured then
    add(
      "settings",
      "error",
      "lua/odoo/local.lua does not exist",
      "run :Odoo setup (or `odoo-nvim setup --workspace DIR`)"
    )
  elseif #settings.problems > 0 then
    add("settings", "warn", table.concat(settings.problems, "; "), "fix them with :Odoo config")
  else
    add("settings", "ok", settings.local_file)
  end
  if vim.fn.isdirectory(settings.core .. "/odoo") == 1 then
    add("odoo core", "ok", settings.core)
  else
    add("odoo core", "warn", "no Odoo source in " .. settings.core, "run :Odoo sync-core (go to definition, debugger)")
  end

  -- what agents know about the commands
  if settings.configured then
    local state, file = require("odoo.agent").status()
    local hints = {
      missing = "agents do not know `odoo-nvim`: run :Odoo ai-init (or `odoo-nvim brief --write`)",
      stale = "the odoo-nvim block of " .. file .. " is out of date: run :Odoo ai-init",
      unreachable = "Claude Code reads CLAUDE.md, which does not import AGENTS.md: add the line @AGENTS.md to " .. file,
    }
    if state == "current" then
      add("agent brief", "ok", file)
    else
      add("agent brief", "warn", state .. " in " .. file, hints[state])
    end
  end

  -- docker
  if not has("docker") then
    add(
      "docker",
      "warn",
      "not found",
      "the Odoo commands (update, test, logs, debug) need Docker with the compose plugin"
    )
    return checks
  end
  add("docker", "ok", first_line({ "docker", "--version" }) or "docker")
  local compose_file = compose.compose_file()
  if not compose_file then
    add("compose file", "error", "none in " .. settings.compose_dir, "set compose_dir in lua/odoo/local.lua")
    return checks
  end
  local service = compose.service_config()
  if next(service) == nil then
    local message = ("service '%s' not found in %s"):format(settings.service, compose_file)
    add("compose file", "error", message, "set service in lua/odoo/local.lua, or check `docker compose config`")
    return checks
  end
  add("compose file", "ok", settings.compose_dir .. "/" .. compose_file .. " (service " .. settings.service .. ")")
  add("database", "ok", compose.db())

  local published = false
  for _, port in ipairs(service.ports or {}) do
    if tonumber(port.target) == settings.debug.port then published = true end
  end
  if published then
    add("debug port", "ok", tostring(settings.debug.port))
  else
    local hint = ('add "%d:%d" to the ports of the %s service'):format(
      settings.debug.port,
      settings.debug.port,
      settings.service
    )
    add("debug port", "warn", settings.debug.port .. " is not published (F5 cannot attach)", hint)
  end

  local status = compose.status()
  if not status.exists then
    add("container", "warn", "not created", "start it with :Odoo start (or `odoo-nvim start`)")
  elseif not status.running then
    add("container", "warn", compose.container() .. " is stopped", "start it with :Odoo start (or `odoo-nvim start`)")
  else
    add("container", "ok", compose.container() .. " is running" .. (status.debug and " (debug mode)" or ""))
    local debugpy = first_line({
      "docker",
      "exec",
      compose.container(),
      "python3",
      "-c",
      "import debugpy; print(debugpy.__version__)",
    })
    if debugpy then
      add("debugpy", "ok", debugpy)
    else
      add(
        "debugpy",
        "warn",
        "not installed in the image",
        "add `RUN pip3 install debugpy` to the Dockerfile (debugger)"
      )
    end
  end
  return checks
end

--- Worst status of a list of checks.
---@param checks OdooHealthCheck[]
---@return "ok"|"warn"|"error"
function M.worst(checks)
  local worst = "ok"
  for _, check in ipairs(checks) do
    if check.status == "error" then return "error" end
    if check.status == "warn" then worst = "warn" end
  end
  return worst
end

--- :checkhealth odoo
function M.check()
  vim.health.start("Odoo development")
  for _, check in ipairs(M.checks()) do
    local text = check.name .. ": " .. check.message
    if check.status == "ok" then
      vim.health.ok(text)
    elseif check.status == "warn" then
      vim.health.warn(text, check.hint)
    else
      vim.health.error(text, check.hint)
    end
  end
end

return M
