-- Odoo-aware fuzzy pickers (built on snacks.nvim picker).
-- Inside any picker: type to filter, <C-j>/<C-k> or arrows to move, <CR> open,
-- <C-v> open in vertical split, <C-s> horizontal split, <Esc> close.
local settings = require("odoo.settings")
local paths = require("odoo.paths")
local M = {}

local ro_glob = { "*.po", "*.pot", "*.min.js", "**/static/lib/**" } -- noise when searching

-- "/…/oca/web/web_responsive/models/x.py" -> "web_responsive", "oca/web"
local dirs_cache
local function module_from_path(file)
  dirs_cache = dirs_cache or paths.addon_dirs()
  for _, d in ipairs(dirs_cache) do
    if file:sub(1, #d + 1) == d .. "/" then
      local rest = file:sub(#d + 2)
      return rest:match("^([^/]+)"), paths.addon_dir_label(d)
    end
  end
  return "?", ""
end

-- Scan results are cached; a save of a .py/.xml file or a git checkout refreshes them.
local cache = {}
function M.clear_cache() cache = {} end
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("odoo_picker_cache", { clear = true }),
  pattern = { "*.py", "*.xml" },
  callback = function() cache = {} end,
})

local rg
local function cached_rg(key, args, dirs, cb)
  if cache[key] then return cb(cache[key]) end
  vim.notify("Scanning addons…", vim.log.levels.INFO, { id = "odoo_scan" })
  rg(args, dirs, function(found)
    cache[key] = found
    Snacks.notifier.hide("odoo_scan")
    cb(found)
  end)
end

function rg(args, dirs, cb)
  local cmd = { "rg", "--no-heading", "--with-filename", "--line-number", "--column", "--no-messages", "--color=never" }
  vim.list_extend(cmd, args)
  vim.list_extend(cmd, dirs)
  vim.system(cmd, { text = true }, function(r)
    local out = {}
    for line in (r.stdout or ""):gmatch("[^\n]+") do
      local f, l, c, t = line:match("^(.-):(%d+):(%d+):(.*)$")
      if f then table.insert(out, { file = f, lnum = tonumber(l), col = tonumber(c), text = t }) end
    end
    vim.schedule(function() cb(out) end)
  end)
end

-- Best guess of "the model I'm looking at": a 'x.y' string under the cursor, else the
-- _name/_inherit of the class around the cursor.
function M.model_under_cursor()
  local word = vim.fn.expand("<cWORD>"):match("['\"]([%w_]+%.[%w_.]+)['\"]")
    or vim.fn.expand("<cWORD>"):match(">([%w_]+%.[%w_.]+)<")
  if word then return word end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = row, 1, -1 do
    local m = lines[i]:match("^%s+_name%s*=%s*['\"]([%w_.]+)")
      or lines[i]:match("^%s+_inherit%s*=%s*%[?%s*['\"]([%w_.]+)")
    if m then return m end
    if i < row and lines[i]:match("^class ") then
      -- also scan the class body below the class line
      for j = i + 1, math.min(i + 25, #lines) do
        local n = lines[j]:match("^%s+_name%s*=%s*['\"]([%w_.]+)")
          or lines[j]:match("^%s+_inherit%s*=%s*%[?%s*['\"]([%w_.]+)")
        if n then return n end
      end
      break
    end
  end
  return nil
end

--- All models: where they are defined (_name) and every extension (_inherit).
function M.models(opts)
  opts = opts or {}
  local pattern = [=[^\s+_(name|inherit)\s*=\s*\[?\s*['"][a-z0-9_.]+['"]]=]
  cached_rg("models", { "-t", "py", "-e", pattern }, paths.addon_dirs(), function(found)
    local items = {}
    for _, r in ipairs(found) do
      local kind, model = r.text:match("_(%a+)%s*=%s*%[?%s*['\"]([%w_.]+)")
      if model then
        local mod, label = module_from_path(r.file)
        table.insert(items, {
          text = model .. " " .. mod .. " " .. label,
          model = model,
          kind = kind,
          module = mod,
          label = label,
          file = r.file,
          pos = { r.lnum, r.col - 1 },
        })
      end
    end
    table.sort(items, function(a, b)
      if a.model ~= b.model then return a.model < b.model end
      if a.kind ~= b.kind then return a.kind == "name" end -- definition first
      return a.module < b.module
    end)
    Snacks.picker.pick({
      title = "Odoo models  (definition ● / extension ○)",
      items = items,
      pattern = opts.pattern,
      format = function(item)
        return {
          { item.kind == "name" and "● " or "○ ", item.kind == "name" and "DiagnosticOk" or "Comment" },
          { ("%-40s"):format(item.model), "Function" },
          { " " .. item.module, "Identifier" },
          { "  " .. item.label, "Comment" },
        }
      end,
      preview = "file",
    })
  end)
end

--- Same, pre-filtered with the model under the cursor.
function M.model_at_cursor()
  local m = M.model_under_cursor()
  M.models({ pattern = m })
end

--- Every XML id (records, templates, menus) of all addons.
function M.xmlids(opts)
  opts = opts or {}
  local pattern = [=[<(record|template|menuitem)\b[^>]*\bid=["'][^"']+["']]=]
  cached_rg("xmlids", { "-t", "xml", "-e", pattern }, paths.addon_dirs(), function(found)
    local items = {}
    for _, r in ipairs(found) do
      local tag = r.text:match("<(%a+)")
      local id = r.text:match("%sid=[\"']([^\"']+)[\"']")
      local model = r.text:match("model=[\"']([^\"']+)[\"']")
        or (tag == "menuitem" and "menu")
        or (tag == "template" and "qweb")
        or ""
      if id then
        local mod, label = module_from_path(r.file)
        local full = id:find("%.") and id or (mod .. "." .. id)
        table.insert(items, {
          text = full .. " " .. model .. " " .. label,
          xmlid = full,
          model = model,
          label = label,
          file = r.file,
          pos = { r.lnum, r.col - 1 },
        })
      end
    end
    Snacks.picker.pick({
      title = "Odoo XML ids",
      items = items,
      pattern = opts.pattern,
      format = function(item)
        return {
          { ("%-55s"):format(item.xmlid), "Function" },
          { " " .. ("%-22s"):format(item.model), "Type" },
          { " " .. item.label, "Comment" },
        }
      end,
      preview = "file",
    })
  end)
end

function M.xmlid_at_cursor()
  local w = vim.fn.expand("<cWORD>"):match("['\"]([%w_]+%.?[%w_]+)['\"]") or vim.fn.expand("<cword>")
  M.xmlids({ pattern = w })
end

--- Views, actions and menus that use a model (form/list/search of sale.order...).
function M.views(model)
  model = model or M.model_under_cursor()
  if not model then
    vim.ui.input({ prompt = "Model (e.g. sale.order): " }, function(m)
      if m and m ~= "" then M.views(m) end
    end)
    return
  end
  local esc = model:gsub("%.", "\\.")
  local pattern = ([=[name=["'](model|res_model|model_id)["'][^>]*>\s*%s\s*<|model=["']%s["']|ref=["']model_%s["']]=]):format(
    esc,
    esc,
    (model:gsub("%.", "_"))
  )
  rg({ "-t", "xml", "-e", pattern }, paths.addon_dirs(), function(found)
    local items, file_lines = {}, {}
    for _, r in ipairs(found) do
      file_lines[r.file] = file_lines[r.file] or vim.fn.readfile(r.file)
      local lines, rid, rmodel = file_lines[r.file], nil, nil
      for i = r.lnum, math.max(1, r.lnum - 15), -1 do
        rid = lines[i]:match("<record[^>]*%sid=[\"']([^\"']+)") or lines[i]:match("<menuitem[^>]*%sid=[\"']([^\"']+)")
        if rid then
          rmodel = lines[i]:match("model=[\"']([^\"']+)") or "menu"
          break
        end
      end
      local mod, label = module_from_path(r.file)
      if rmodel ~= model then -- skip records OF the model itself (data), keep views/actions/rules
        table.insert(items, {
          text = (rid or "?") .. " " .. (rmodel or "") .. " " .. mod,
          rid = rid or vim.fs.basename(r.file),
          rmodel = rmodel or "",
          module = mod,
          label = label,
          file = r.file,
          pos = { r.lnum, 0 },
        })
      end
    end
    Snacks.picker.pick({
      title = "Views / actions / rules using " .. model,
      items = items,
      format = function(item)
        return {
          { ("%-22s"):format(item.rmodel), "Type" },
          { " " .. ("%-50s"):format(item.module .. "." .. item.rid), "Function" },
          { " " .. item.label, "Comment" },
        }
      end,
      preview = "file",
    })
  end)
end

--- All modules. <CR> opens the manifest, <C-e> opens the module in the file explorer.
function M.modules(opts)
  opts = opts or {}
  local items = {}
  for _, d in ipairs(paths.addon_dirs()) do
    for name, t in vim.fs.dir(d) do
      local manifest = d .. "/" .. name .. "/__manifest__.py"
      if t == "directory" and vim.uv.fs_stat(manifest) then
        local _, label = module_from_path(manifest)
        table.insert(
          items,
          { text = name .. " " .. label, name = name, label = label, dir = d .. "/" .. name, file = manifest }
        )
      end
    end
  end
  table.sort(items, function(a, b) return a.name < b.name end)
  Snacks.picker.pick({
    title = opts.title or "Odoo modules  (<CR> manifest · <C-e> explorer)",
    items = items,
    format = function(item) return { { ("%-45s"):format(item.name), "Function" }, { " " .. item.label, "Comment" } } end,
    preview = "file",
    confirm = opts.confirm,
    actions = {
      explore = function(picker, item)
        picker:close()
        vim.cmd("Neotree dir=" .. vim.fn.fnameescape(item.dir))
      end,
    },
    win = { input = { keys = { ["<c-e>"] = { "explore", mode = { "n", "i" } } } } },
  })
end

--- Pick a module and call fn(name)
function M.pick_module(title, fn)
  M.modules({
    title = title,
    confirm = function(picker, item)
      picker:close()
      if item then fn(item.name) end
    end,
  })
end

-- ------------------------------------------------------------------ scoped search
local function module_dir()
  local name, dir = paths.module_of()
  if not dir then vim.notify("Not inside an Odoo module", vim.log.levels.WARN) end
  return dir, name
end

function M.files_module()
  local dir, name = module_dir()
  if dir then Snacks.picker.files({ dirs = { dir }, title = "Files in " .. name }) end
end
function M.grep_module()
  local dir, name = module_dir()
  if dir then Snacks.picker.grep({ dirs = { dir }, title = "Grep in " .. name }) end
end
function M.files_core()
  Snacks.picker.files({ dirs = { settings.core }, title = "Files in Odoo core", exclude = ro_glob })
end
function M.grep_core() Snacks.picker.grep({ dirs = { settings.core }, title = "Grep in Odoo core", exclude = ro_glob }) end
function M.files_addons()
  Snacks.picker.files({ dirs = paths.addon_dirs(), title = "Files in ALL addons", exclude = ro_glob })
end
function M.grep_addons()
  Snacks.picker.grep({ dirs = paths.addon_dirs(), title = "Grep in ALL addons (core+oca+yours)", exclude = ro_glob })
end
function M.grep_word_addons()
  Snacks.picker.grep_word({ dirs = paths.addon_dirs(), title = "Word in ALL addons", exclude = ro_glob })
end

return M
