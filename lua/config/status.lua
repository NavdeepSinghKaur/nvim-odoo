-- Small statusline helpers (used by lualine in lua/plugins/ui.lua).
--
-- Why not popups? Any floating window on screen (sticky context header, progress notification)
-- forces Neovim to repaint the WHOLE terminal on every scroll step (~25x more output), which
-- feels laggy when scrolling fast. So this info lives in the statusline instead.
local M = {}

-- ------------------------------------------------------------------ breadcrumb
-- "HrExpense › _compute_journal_id" (Python) or "record#view_expenses_form › xpath" (XML)
local function xml_tag(node, buf)
  for child in node:iter_children() do
    local t = child:type()
    if t == "STag" or t == "EmptyElemTag" then
      local name, attrs = nil, {}
      for c in child:iter_children() do
        if c:type() == "Name" then
          name = vim.treesitter.get_node_text(c, buf)
        elseif c:type() == "Attribute" then
          local k, v
          for a in c:iter_children() do
            if a:type() == "Name" then k = vim.treesitter.get_node_text(a, buf) end
            if a:type() == "AttValue" then v = vim.treesitter.get_node_text(a, buf):sub(2, -2) end
          end
          if k then attrs[k] = v end
        end
      end
      return name, attrs
    end
  end
end

local xml_shown = { record = "id", template = "id", menuitem = "id", xpath = "expr", page = "name", group = "name" }

function M.breadcrumb()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  if ft ~= "python" and ft ~= "xml" then return "" end
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, ignore_injections = true })
  if not ok or not node then return "" end
  local parts = {}
  while node do
    local t = node:type()
    if t == "class_definition" or t == "function_definition" then
      local name = node:field("name")[1]
      if name then
        table.insert(parts, 1, (t == "class_definition" and "󰠱 " or "󰊕 ") .. vim.treesitter.get_node_text(name, buf))
      end
    elseif t == "element" then
      local name, attrs = xml_tag(node, buf)
      local key = name and xml_shown[name]
      if key then
        local v = attrs[key] or ""
        if #v > 40 then v = v:sub(1, 37) .. "…" end
        table.insert(parts, 1, name .. (v ~= "" and (" " .. v) or ""))
      end
    end
    node = node:parent()
  end
  return table.concat(parts, " › ")
end

-- ------------------------------------------------------------------ LSP progress
-- e.g. "⠹ odoo_ls: Indexing modules 45%" while odoo_ls indexes (~15 s after startup)
local active = {} -- token -> text
local order = {}
local last_redraw = 0

vim.api.nvim_create_autocmd("LspProgress", {
  group = vim.api.nvim_create_augroup("status_lsp_progress", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local value = ev.data.params.value
    if not client or type(value) ~= "table" then return end
    local token = client.id .. ":" .. tostring(ev.data.params.token)
    if value.kind == "end" then
      active[token] = nil
    else
      if not active[token] then table.insert(order, token) end
      local detail = value.percentage and (value.percentage .. "%") or (value.message or "")
      detail = detail:gsub(" items remaining", " left")
      local text = ("%s %s %s"):format(client.name, (value.title or ""):gsub("^Odoo: ", ""), detail)
      active[token] = #text > 38 and (text:sub(1, 37) .. "…") or text
    end
    local now = vim.uv.now()
    if value.kind == "end" or now - last_redraw > 150 then -- odoo_ls sends hundreds per second
      last_redraw = now
      vim.cmd.redrawstatus()
    end
  end,
})

local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
function M.lsp_progress()
  for i = #order, 1, -1 do
    local text = active[order[i]]
    if text then
      return spinner[math.floor(vim.uv.hrtime() / (1e6 * 120)) % #spinner + 1] .. " " .. text
    end
    table.remove(order, i)
  end
  return ""
end

return M
