-- Works out the settings of lua/odoo/local.lua from a project on disk, for :Odoo setup and
-- `odoo-nvim setup`: the compose file gives the services, the container name and the mounted
-- folders; the mounted odoo.conf gives the addons path.
-- What cannot be known (which addons are yours, your Python) is guessed and listed in `notes`.
local M = {}

local COMPOSE_FILES = { "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml" }
local DEFAULT_CONF = "/etc/odoo/odoo.conf"
local DEFAULT_CORE_REMOTE = "/usr/lib/python3/dist-packages/odoo"

---@param path string
---@return string
local function norm(path) return (vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p")):gsub("/$", "")) end

local function is_dir(path) return vim.fn.isdirectory(path) == 1 end
local function inside(path, dir) return path == dir or path:sub(1, #dir + 1) == dir .. "/" end

---@param dir string
---@return boolean
function M.has_compose_file(dir)
  for _, name in ipairs(COMPOSE_FILES) do
    if vim.uv.fs_stat(dir .. "/" .. name) then return true end
  end
  return false
end

--- The compose project of `dir` as docker resolves it (absolute volume paths, merged files).
---@param dir string
---@return table? config, string? error
function M.compose_config(dir)
  local ran, result = pcall(
    function()
      return vim.system({ "docker", "compose", "config", "--format", "json" }, { text = true, cwd = dir }):wait()
    end
  )
  if not ran then return nil, "docker is not installed" end
  if result.code ~= 0 then return nil, vim.trim(result.stderr or "") end
  local ok, config = pcall(vim.json.decode, result.stdout, { luanil = { object = true, array = true } })
  if not ok or type(config) ~= "table" or not config.services then
    return nil, "unexpected output of docker compose config"
  end
  return config
end

--- Folders that bind-mount into a service: { { remote = "/mnt/x", ["local"] = "/home/me/x" } },
--- most specific container path first.
---@param service table
---@return OdooPathMapping[]
local function binds(service)
  local list = {}
  for _, volume in ipairs(service.volumes or {}) do
    if volume.type == "bind" and volume.source and volume.target then
      table.insert(list, { remote = volume.target, ["local"] = volume.source })
    end
  end
  table.sort(list, function(a, b) return #a.remote > #b.remote end)
  return list
end

---@param mappings OdooPathMapping[]
---@param remote string
---@return string? local path, nil when the path is not mounted from this machine
local function to_local(mappings, remote)
  for _, mapping in ipairs(mappings) do
    if inside(remote, mapping.remote) then return mapping["local"] .. remote:sub(#mapping.remote + 1) end
  end
end

--- Does one of the services mount something from inside `workspace`?
local function mounts_workspace(config, workspace)
  for _, service in pairs(config.services) do
    for _, mapping in ipairs(binds(service)) do
      if inside(mapping["local"], workspace) then return true end
    end
  end
  return false
end

--- The folder with the compose file of this project: the workspace itself, its docker/
--- folder, or a folder next to it whose compose file mounts the workspace.
---@param workspace string
---@return string? dir, table? config
function M.find_compose_dir(workspace)
  local candidates = { workspace, workspace .. "/docker" }
  local parent = vim.fs.dirname(workspace)
  for name, kind in vim.fs.dir(parent) do
    if kind ~= "file" and not name:match("^%.") then table.insert(candidates, parent .. "/" .. name) end
  end
  for index, dir in ipairs(candidates) do
    if M.has_compose_file(dir) then
      local config = M.compose_config(dir)
      if config and (index <= 2 or mounts_workspace(config, workspace)) then return dir, config end
    end
  end
end

--- Name of the first service (alphabetically) that `matches`, preferring one called `preferred`.
local function find_service(config, preferred, matches)
  if config.services[preferred] then return preferred end
  local names = vim.tbl_keys(config.services)
  table.sort(names)
  for _, name in ipairs(names) do
    if matches(config.services[name]) then return name end
  end
end

local function command_text(service)
  local command = service.command
  return type(command) == "table" and table.concat(command, " ") or tostring(command or "")
end

--- The value of a command line option: `-c x`, `--config x` or `--config=x`.
local function command_option(service, short, long)
  local command = type(service.command) == "table" and service.command or {}
  for i, arg in ipairs(command) do
    if arg == short or arg == long then return command[i + 1] end
    local value = arg:match("^" .. vim.pesc(long) .. "=(.+)")
    if value then return value end
  end
end

--- The addons_path of an odoo.conf file, as the container sees it.
---@param file string
---@return string[]
local function conf_addons_path(file)
  if vim.fn.filereadable(file) == 0 then return {} end
  for _, line in ipairs(vim.fn.readfile(file)) do
    local value = line:match("^%s*addons_path%s*=%s*(.+)$")
    if value then return vim.split(value, "%s*,%s*", { trimempty = true }) end
  end
  return {}
end

--- Does this folder directly contain Odoo modules?
local function has_modules(dir)
  for name, kind in vim.fs.dir(dir) do
    if kind ~= "file" and vim.uv.fs_stat(dir .. "/" .. name .. "/__manifest__.py") then return true end
  end
  return false
end

--- Does this folder hold modules, or repos of modules (oca/ with web/, server-tools/...)?
local function looks_like_addons(dir)
  if not is_dir(dir) then return false end
  if has_modules(dir) then return true end
  for name, kind in vim.fs.dir(dir) do
    if kind ~= "file" and not name:match("^%.") and has_modules(dir .. "/" .. name) then return true end
  end
  return false
end

---@param list string[]
---@param value string
local function add_once(list, value)
  if not vim.tbl_contains(list, value) then table.insert(list, value) end
end

--- Replace several repos of one folder (oca/web, oca/server-tools...) by that folder.
---@param dirs string[]
---@param workspace string
---@return string[]
local function group_by_parent(dirs, workspace)
  local count = {}
  for _, dir in ipairs(dirs) do
    local parent = vim.fs.dirname(dir)
    count[parent] = (count[parent] or 0) + 1
  end
  local grouped = {}
  for _, dir in ipairs(dirs) do
    local parent = vim.fs.dirname(dir)
    local group = count[parent] > 1 and parent ~= workspace and inside(parent, workspace)
    add_once(grouped, group and parent or dir)
  end
  return grouped
end

---@class OdooDetectOptions
---@field workspace string the repo you work in
---@field compose_dir? string folder with the compose file (default: searched)
---@field service? string odoo service name (default: detected)
---@field db_service? string postgres service name (default: detected)
---@field own? string[] addons folders with YOUR code (default: guessed)
---@field python? string Python with Odoo's requirements
---@field core? string Odoo source checkout (default: copied from the image by :Odoo sync-core)

---@class OdooDetected
---@field values table the local.lua table
---@field notes string[] what was guessed or could not be found: check these

--- Work out the local.lua values for a project.
---@param opts OdooDetectOptions
---@return OdooDetected? detected, string? error
function M.detect(opts)
  local workspace = norm(opts.workspace)
  if not is_dir(workspace) then return nil, "no such folder: " .. workspace end
  local values, notes = { workspace = workspace }, {}

  local compose_dir, config
  if opts.compose_dir then
    compose_dir = norm(opts.compose_dir)
    local problem
    config, problem = M.compose_config(compose_dir)
    if not config then return nil, "docker compose config failed in " .. compose_dir .. ": " .. (problem or "") end
  else
    compose_dir, config = M.find_compose_dir(workspace)
  end

  local addons, mappings, conf_paths = {}, {}, {}
  if compose_dir and config then
    values.compose_dir = compose_dir
    local service_name = opts.service
      or find_service(
        config,
        "odoo",
        function(service)
          return (service.image or ""):find("odoo", 1, true) or command_text(service):find("odoo", 1, true)
        end
      )
    local db_name = opts.db_service
      or find_service(config, "db", function(service) return (service.image or ""):find("postgres", 1, true) end)
    local service = service_name and config.services[service_name]
    if not service then
      return nil, "no odoo service found in the compose file of " .. compose_dir .. " (use --service)"
    end
    values.service = service_name
    values.db_service = db_name
    if not db_name then table.insert(notes, "no postgres service found: set db_service (psql, :Odoo db)") end
    values.container = service.container_name
    local db_service = db_name and config.services[db_name]
    local db_user = db_service and (db_service.environment or {}).POSTGRES_USER
    if db_user and db_user ~= "odoo" then values.db_user = db_user end

    local conf = command_option(service, "-c", "--config") or DEFAULT_CONF
    if conf ~= DEFAULT_CONF then values.odoo_conf = conf end
    mappings = binds(service)
    conf_paths = conf_addons_path(to_local(mappings, conf) or "")
    if #conf_paths == 0 then
      table.insert(notes, "addons_path of " .. conf .. " could not be read: addons folders taken from the volumes")
      for _, mapping in ipairs(mappings) do
        if looks_like_addons(mapping["local"]) then table.insert(conf_paths, mapping.remote) end
      end
    end
  else
    table.insert(notes, "no compose file found for this workspace: set compose_dir (or use --compose-dir)")
  end

  for _, remote in ipairs(conf_paths) do
    local dir = to_local(mappings, remote)
    if dir and is_dir(dir) then
      add_once(addons, norm(dir))
    elseif not dir and remote:match("/odoo/addons$") then
      local core_remote = remote:gsub("/addons$", "")
      if core_remote ~= DEFAULT_CORE_REMOTE then values.core_remote = core_remote end
    end
  end
  if #addons == 0 and looks_like_addons(workspace) then table.insert(addons, workspace) end

  -- Yours or not? An addons folder that is its own git repo (a submodule, a clone of an OCA
  -- repo) is somebody else's code; what belongs to the workspace repo is taken as yours.
  local own, vendored = {}, {}
  if opts.own then
    own = vim.tbl_map(norm, opts.own)
    for _, dir in ipairs(addons) do
      if not vim.tbl_contains(own, dir) then table.insert(vendored, dir) end
    end
    for _, dir in ipairs(own) do
      add_once(addons, dir)
    end
  else
    local workspace_repo = vim.fs.root(workspace, ".git")
    local function is_foreign(dir) return not inside(dir, workspace) or vim.fs.root(dir, ".git") ~= workspace_repo end
    local foreign_parents = {} -- folders holding at least one foreign repo: everything in them is taken as foreign
    for _, dir in ipairs(addons) do
      if is_foreign(dir) then foreign_parents[vim.fs.dirname(dir)] = true end
    end
    foreign_parents[workspace] = nil
    for _, dir in ipairs(addons) do
      local foreign = is_foreign(dir) or foreign_parents[vim.fs.dirname(dir)]
      table.insert(foreign and vendored or own, dir)
    end
    if #own ~= 1 then
      table.insert(
        notes,
        ("own_addons is a guess (%d folder(s) of the workspace repo): keep only the code YOU write, "):format(#own)
          .. "move the rest to readonly_paths (or use --own)"
      )
    end
  end

  values.core = opts.core and norm(opts.core) or (vim.fn.stdpath("data") .. "/odoo-core")
  if not is_dir(values.core) then
    table.insert(notes, "Odoo core is not there yet: run :Odoo sync-core (copies it from the image)")
  end
  values.own_addons = #own > 0 and own or nil
  values.addons_paths = #addons > 0 and group_by_parent(addons, workspace) or nil
  values.readonly_paths = vim.list_extend({ values.core }, group_by_parent(vendored, workspace))
  if opts.python then
    values.python = norm(opts.python)
  else
    table.insert(notes, "python is the system python3: set it to a venv with Odoo's requirements for better completion")
  end
  return { values = values, notes = notes }
end

-- ------------------------------------------------------------------ writing local.lua
local KEY_ORDER = {
  "workspace",
  "own_addons",
  "core",
  "addons_paths",
  "readonly_paths",
  "python",
  "compose_dir",
  "service",
  "db_service",
  "container",
  "db_user",
  "odoo_conf",
  "core_remote",
}

--- A path as Lua source, with the home folder written as ~ (settings.lua expands it).
local function quoted(value)
  local home = vim.env.HOME
  if home and inside(value, home) then value = "~" .. value:sub(#home + 1) end
  return ("%q"):format(value)
end

--- The text of a local.lua file for detected values.
---@param detected OdooDetected
---@return string[] lines
function M.render(detected)
  local lines = {
    "-- Your Odoo setup, written by :Odoo setup / `odoo-nvim setup`. Edit it freely.",
    "-- Every option: lua/odoo/local.example.lua     Check the result: :Odoo info, :checkhealth odoo",
  }
  for _, note in ipairs(detected.notes) do
    table.insert(lines, "-- CHECK: " .. note)
  end
  table.insert(lines, "return {")
  for _, key in ipairs(KEY_ORDER) do
    local value = detected.values[key]
    if type(value) == "table" then
      table.insert(lines, "  " .. key .. " = {")
      for _, item in ipairs(value) do
        table.insert(lines, "    " .. quoted(item) .. ",")
      end
      table.insert(lines, "  },")
    elseif value ~= nil then
      table.insert(lines, "  " .. key .. " = " .. quoted(value) .. ",")
    end
  end
  table.insert(lines, "}")
  return lines
end

--- Detect and write local.lua.
---@param opts OdooDetectOptions
---@param file string where to write (lua/odoo/local.lua)
---@param force? boolean replace an existing file (it is kept as <file>.bak)
---@return OdooDetected? detected, string? error
function M.write(opts, file, force)
  if vim.uv.fs_stat(file) and not force then
    return nil, file .. " exists (use --force, the old one is kept as local.lua.bak)"
  end
  local detected, problem = M.detect(opts)
  if not detected then return nil, problem end
  if vim.uv.fs_stat(file) then vim.uv.fs_copyfile(file, file .. ".bak") end
  vim.fn.writefile(M.render(detected), file)
  return detected
end

return M
