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

--- Create a small project and load settings for it (as if local.lua returned them):
---   ws/custom/my_mod          your code
---   ws/oca/web/web_responsive a folder of repos (read-only)
---   core/odoo/addons/sale     Odoo core
---@param overrides? table local.lua values to change
---@return OdooSettings settings, string root
function H.project(overrides)
  local root = H.tmpdir()
  H.write(root .. "/ws/custom/my_mod/__manifest__.py", { "{}" })
  H.write(root .. "/ws/custom/my_mod/models/thing.py", { "class Thing: pass" })
  H.write(root .. "/ws/oca/web/web_responsive/__manifest__.py", { "{}" })
  H.write(root .. "/core/odoo/addons/sale/__manifest__.py", { "{}" })
  H.write(root .. "/core/odoo/models.py", { "# core" })
  vim.fn.mkdir(root .. "/docker", "p")

  local user = vim.tbl_extend("force", {
    workspace = root .. "/ws",
    own_addons = { root .. "/ws/custom" },
    core = root .. "/core",
    addons_paths = { root .. "/ws/custom", root .. "/ws/oca" },
    readonly_paths = { root .. "/core", root .. "/ws/oca" },
    python = "/usr/bin/python3",
    compose_dir = root .. "/docker",
    container = "odoo_web",
    debug = { extra_args = { "--dev=xml" } },
    path_mappings = {
      { remote = "/mnt/custom", ["local"] = root .. "/ws/custom" },
      { remote = "/mnt/oca", ["local"] = root .. "/ws/oca" },
    },
  }, overrides or {})

  H.reset()
  local settings = require("odoo.settings").load(user)
  return settings, root
end

return H
