-- Shared test helpers: a throw-away Odoo project on disk and the settings that point at it.
local H = {}

--- A fresh, empty temporary directory (real path, no symlinks).
---@return string
function H.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return assert(vim.uv.fs_realpath(dir))
end

--- Write `lines` to `path`, creating the parent folders.
---@param path string
---@param lines? string[]
function H.write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or {}, path)
end

--- Forget every loaded `odoo.*` module so the next require starts clean.
function H.reset()
  for name in pairs(package.loaded) do
    if name == "odoo" or name:match("^odoo%.") then package.loaded[name] = nil end
  end
end

--- Create a small project and install fake settings for it:
---   ws/custom/my_mod          your code
---   ws/oca/web/web_responsive a folder of repos (read-only)
---   core/odoo/addons/sale     Odoo core
---@param overrides? table settings to change
---@return table settings, string root
function H.project(overrides)
  local root = H.tmpdir()
  H.write(root .. "/ws/custom/my_mod/__manifest__.py", { "{}" })
  H.write(root .. "/ws/custom/my_mod/models/thing.py", { "class Thing: pass" })
  H.write(root .. "/ws/oca/web/web_responsive/__manifest__.py", { "{}" })
  H.write(root .. "/core/odoo/addons/sale/__manifest__.py", { "{}" })
  H.write(root .. "/core/odoo/models.py", { "# core" })
  vim.fn.mkdir(root .. "/docker", "p")

  local settings = vim.tbl_extend("force", {
    workspace = root .. "/ws",
    own_addons = { root .. "/ws/custom" },
    core = root .. "/core",
    core_addons = root .. "/core/odoo/addons",
    addons_paths = { root .. "/ws/custom", root .. "/ws/oca", root .. "/core/odoo/addons" },
    readonly_paths = { root .. "/core", root .. "/ws/oca" },
    python = "/usr/bin/python3",
    compose_dir = root .. "/docker",
    service = "odoo",
    db_service = "db",
    container = "odoo_web",
    odoo_conf = "/etc/odoo/odoo.conf",
    odoo_bin = "/usr/bin/odoo",
    db_user = "odoo",
    core_remote = "/usr/lib/python3/dist-packages/odoo",
    oneoff_args = { "--http-port=8071", "--gevent-port=8073" },
    debug = { host = "127.0.0.1", port = 5678, extra_args = { "--dev=xml" } },
    path_mappings = {
      { remote = "/mnt/custom", ["local"] = root .. "/ws/custom" },
      { remote = "/mnt/oca", ["local"] = root .. "/ws/oca" },
    },
    web_url = "http://localhost:8069",
    odoo_ls_cmd = "odoo_ls_server",
  }, overrides or {})

  H.reset()
  package.loaded["odoo.settings"] = settings
  return settings, root
end

return H
