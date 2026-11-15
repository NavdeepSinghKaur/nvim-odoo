-- Path helpers: which module am I in, container <-> local paths, is this my code...
local settings = require("odoo.settings")
local M = {}

---@param path string
---@return string path absolute and normalized (no trailing slash)
local function norm(path) return (vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")) end

--- Is the normalized `path` the normalized `dir` or something inside it?
local function inside(path, dir) return path == dir or path:sub(1, #dir + 1) == dir .. "/" end

--- Is `path` inside one of `dirs`?
---@param path? string
---@param dirs string[]
---@return boolean
function M.under_any(path, dirs)
  if not path or path == "" then return false end
  path = norm(path)
  for _, dir in ipairs(dirs) do
    if inside(path, norm(dir)) then return true end
  end
  return false
end

-- The folder lists of the settings, normalized once: these checks run for every buffer
-- (language server roots, format on save, read-only warning).
local folders = {}

---@param name string cache key
---@param list fun(): string[]
---@return fun(path?: string): boolean
local function inside_folders(name, list)
  return function(path)
    if not path or path == "" then return false end
    folders[name] = folders[name] or vim.tbl_map(norm, list())
    path = norm(path)
    for _, dir in ipairs(folders[name]) do
      if inside(path, dir) then return true end
    end
    return false
  end
end

--- Code you write (settings.own_addons)
M.is_own = inside_folders("own", function() return settings.own_addons end)
--- Code you only read (settings.readonly_paths)
M.is_readonly = inside_folders("readonly", function() return settings.readonly_paths end)
--- Odoo core or any addons folder
M.is_odoo = inside_folders("odoo", function() return vim.list_extend({ settings.core }, settings.addons_paths) end)

--- Module of a file: walks up until a folder with __manifest__.py. Returns name, dir.
function M.module_of(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then path = vim.fn.getcwd() end
  local manifest = vim.fs.find("__manifest__.py", { path = vim.fs.dirname(norm(path)), upward = true })[1]
  if not manifest then
    if vim.fn.filereadable(norm(path) .. "/__manifest__.py") == 1 then
      return vim.fs.basename(norm(path)), norm(path)
    end
    return nil
  end
  local dir = vim.fs.dirname(manifest)
  return vim.fs.basename(dir), dir
end

--- Container path <-> local path pairs, most specific first: { { remote = , ["local"] = } }
--- From settings.path_mappings, or else the bind volumes of the odoo service in the compose file.
local mappings_cache
function M.mappings()
  if mappings_cache then return mappings_cache end
  local list = vim.deepcopy(settings.path_mappings or {})
  if not settings.path_mappings then
    for _, v in ipairs(require("odoo.compose").service_config().volumes or {}) do
      if v.type == "bind" and v.source and v.target then
        table.insert(list, { remote = v.target, ["local"] = v.source })
      end
    end
    table.sort(list, function(a, b) return #a.remote > #b.remote end)
  end
  local has_core = false
  for _, m in ipairs(list) do
    has_core = has_core or m.remote == settings.core_remote
  end
  if not has_core then table.insert(list, { remote = settings.core_remote, ["local"] = settings.core .. "/odoo" }) end
  mappings_cache = list
  return list
end

--- Container path -> local path ("/mnt/extra-addons/x/models/a.py" -> "~/odoo/my-addons/x/models/a.py")
function M.to_local(p)
  for _, m in ipairs(M.mappings()) do
    if p:sub(1, #m.remote) == m.remote then return m["local"] .. p:sub(#m.remote + 1) end
  end
  return p
end

--- Local path -> container path
function M.to_remote(p)
  p = norm(p)
  for _, m in ipairs(M.mappings()) do
    local l = norm(m["local"])
    if p:sub(1, #l) == l then return m.remote .. p:sub(#l + 1) end
  end
  return p
end

-- Does this folder directly contain Odoo modules?
local function has_modules(dir)
  for name, t in vim.fs.dir(dir) do
    if t ~= "file" and vim.uv.fs_stat(dir .. "/" .. name .. "/__manifest__.py") then return true end
  end
  return false
end

--- All addon folders that exist. A folder of repos (oca/ holding web/, server-tools/...) is
--- expanded: each repo inside it is its own addons folder.
local addon_dirs_cache
function M.addon_dirs()
  if addon_dirs_cache then return vim.deepcopy(addon_dirs_cache) end
  local dirs = {}
  for _, d in ipairs(settings.addons_paths) do
    if vim.fn.isdirectory(d) == 1 then
      if d == settings.core_addons or has_modules(d) then
        table.insert(dirs, d)
      else
        local n = #dirs
        for name, t in vim.fs.dir(d) do
          local sub = d .. "/" .. name
          if t ~= "file" and not name:match("^%.") and has_modules(sub) then table.insert(dirs, sub) end
        end
        if #dirs == n then table.insert(dirs, d) end -- empty for now
      end
    end
  end
  addon_dirs_cache = dirs
  return vim.deepcopy(dirs)
end

--- Odoo version of the core source, e.g. "18.0" (nil when the core copy is missing).
---@return string?
function M.odoo_version()
  local release = settings.core .. "/odoo/release.py"
  if vim.fn.filereadable(release) == 0 then return nil end
  for _, line in ipairs(vim.fn.readfile(release)) do
    local major, minor = line:match("^version_info%s*=%s*%(%s*(%d+)%s*,%s*(%d+)")
    if major then return major .. "." .. minor end
  end
end

--- Forget everything derived from the settings and the compose file.
function M.reset()
  folders, mappings_cache, addon_dirs_cache = {}, nil, nil
end

--- "core", "web" (repo inside a folder of repos -> "oca/web") or the folder name
function M.addon_dir_label(d)
  if d == settings.core_addons then return "core" end
  if vim.tbl_contains(settings.addons_paths, d) then return vim.fs.basename(d) end
  return vim.fs.basename(vim.fs.dirname(d)) .. "/" .. vim.fs.basename(d)
end

return M
