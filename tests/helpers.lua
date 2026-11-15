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

--- Put the fake `docker` of tests/fake-docker first on PATH, answering from a new folder.
--- Write config.json / test.log / update.log into the returned folder.
---@return string dir
function H.fake_docker()
  local dir = H.tmpdir()
  local fake = vim.fn.fnamemodify("tests/fake-docker", ":p"):gsub("/$", "")
  if not vim.env.PATH:find(fake, 1, true) then vim.env.PATH = fake .. ":" .. vim.env.PATH end
  vim.env.FAKE_DOCKER = dir
  vim.env.FAKE_DOCKER_EXIT = nil
  return dir
end

--- `docker compose config` output for a project made by H.project(): an odoo service that
--- mounts the addons folders and a config folder with an odoo.conf, and a postgres service.
---@param root string
---@return string json
function H.compose_config(root)
  H.write(root .. "/docker/docker-compose.yml", { "services: {}" })
  H.write(root .. "/docker/config/odoo.conf", {
    "[options]",
    "addons_path = /usr/lib/python3/dist-packages/odoo/addons, /mnt/custom, /mnt/oca/web",
  })
  vim.fn.mkdir(root .. "/ws/oca/web/.git", "p") -- an OCA repo cloned into the workspace
  vim.fn.mkdir(root .. "/ws/.git", "p")
  return vim.json.encode({
    services = {
      web = {
        image = "odoo:18.0",
        container_name = "project_web",
        command = { "odoo", "-c", "/etc/odoo/odoo.conf", "-d", "projectdb" },
        ports = { { target = 8069, published = "8069" }, { target = 5678, published = "5678" } },
        volumes = {
          { type = "bind", source = root .. "/ws/custom", target = "/mnt/custom" },
          { type = "bind", source = root .. "/ws/oca", target = "/mnt/oca" },
          { type = "bind", source = root .. "/docker/config", target = "/etc/odoo" },
          { type = "volume", source = "odoo-data", target = "/var/lib/odoo" },
        },
      },
      postgres = { image = "postgres:16", environment = { POSTGRES_USER = "admin" } },
    },
  })
end

return H
