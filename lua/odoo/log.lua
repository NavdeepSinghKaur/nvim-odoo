-- Output panel for Odoo commands (update, tests, logs...).
--   <CR>  on a traceback / "while parsing" line -> open that file at that line (container path
--         is translated to your local path)
--   q     close panel        <C-c> stop the running command
-- When a command ends, every traceback location is put in the quickfix list (<Space>xq).
local M = {}

local ns = vim.api.nvim_create_namespace("odoo_log")
M.jobs = {} -- title -> job id (running)

local traceback = require("odoo.traceback")

M.parse_location = traceback.parse_location
M.to_qf = traceback.to_qf

local function highlight(buf)
  vim.api.nvim_buf_call(
    buf,
    function()
      vim.cmd([[
      syntax clear
      syntax match OdooLogError /\v<(ERROR|CRITICAL)>.*/
      syntax match OdooLogError /\v^(FAIL|ERROR):.*/
      syntax match OdooLogError /\v^\S*(Error|Exception):.*/
      syntax match OdooLogWarn  /\v<WARNING>/
      syntax match OdooLogInfo  /\v<INFO>/
      syntax match OdooLogFile  /\vFile "[^"]+", line \d+/
      syntax match OdooLogFile  /\vwhile parsing \S+/
      syntax match OdooLogOk    /\v<0 failed, 0 error\(s\).*/
      syntax match OdooLogOk    /\v^OK.*/
      syntax match OdooLogCmd   /\v^\$ .*/
      syntax match OdooLogDate  /\v^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d+/
    ]])
    end
  )
  vim.api.nvim_set_hl(0, "OdooLogError", { link = "DiagnosticError", default = true })
  vim.api.nvim_set_hl(0, "OdooLogWarn", { link = "DiagnosticWarn", default = true })
  vim.api.nvim_set_hl(0, "OdooLogInfo", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "OdooLogFile", { link = "Underlined", default = true })
  vim.api.nvim_set_hl(0, "OdooLogOk", { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "OdooLogCmd", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "OdooLogDate", { link = "Comment", default = true })
end

local function jump_from_line()
  local f, l = M.parse_location(vim.api.nvim_get_current_line())
  if not f then
    vim.notify("No file:line on this line", vim.log.levels.WARN)
    return
  end
  vim.cmd("wincmd p")
  if vim.bo.filetype == "odoolog" then vim.cmd("aboveleft split") end
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  pcall(vim.api.nvim_win_set_cursor, 0, { l, 0 })
  vim.cmd("normal! zz")
end

local function get_buf(title)
  local name = "odoo://" .. title
  local buf = vim.fn.bufnr(name)
  if buf == -1 or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].filetype = "odoolog"
    vim.bo[buf].bufhidden = "hide"
    local o = { buffer = buf, silent = true }
    vim.keymap.set("n", "<CR>", jump_from_line, vim.tbl_extend("force", o, { desc = "Open file:line" }))
    vim.keymap.set("n", "gf", jump_from_line, vim.tbl_extend("force", o, { desc = "Open file:line" }))
    vim.keymap.set("n", "<C-c>", function() M.stop(title) end, vim.tbl_extend("force", o, { desc = "Stop" }))
    vim.keymap.set("n", "q", "<Cmd>close<CR>", vim.tbl_extend("force", o, { desc = "Close" }))
    highlight(buf)
  end
  return buf
end

local function show(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then return win end
  end
  -- reuse any visible odoo log window
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "odoolog" then
      vim.api.nvim_win_set_buf(win, buf)
      return win
    end
  end
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("botright 15split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].winfixheight = true
  vim.api.nvim_set_current_win(cur)
  return win
end

function M.stop(title)
  local id = M.jobs[title]
  if id then
    vim.fn.jobstop(id)
    M.jobs[title] = nil
    vim.notify("Stopped: " .. title)
  end
end

function M.running()
  local t = {}
  for title in pairs(M.jobs) do
    table.insert(t, title)
  end
  return t
end

--- Run a command and stream its output into the panel.
--- opts = { title, cmd (list), cwd, on_exit(code, lines), quickfix (bool, default true) }
function M.run(opts)
  local title = opts.title
  if M.jobs[title] then M.stop(title) end
  local buf = get_buf(title)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ " .. table.concat(opts.cmd, " "), "" })
  vim.bo[buf].modifiable = false
  local win = show(buf)
  local all, partial = {}, { "" }

  local function append(data)
    if not data then return end
    -- jobstart splits on \n; the last element is a partial line
    data[1] = partial[1] .. data[1]
    partial[1] = table.remove(data)
    if #data == 0 then return end
    for i, l in ipairs(data) do
      data[i] = l:gsub("\r", "")
    end
    vim.list_extend(all, data)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      local follow = true
      if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
        follow = vim.api.nvim_win_get_cursor(win)[1] >= vim.api.nvim_buf_line_count(buf) - 1
      end
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
      vim.bo[buf].modifiable = false
      if follow and win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
      end
    end)
  end

  local id = vim.fn.jobstart(opts.cmd, {
    cwd = opts.cwd,
    stdout_buffered = false,
    on_stdout = function(_, d) append(d) end,
    on_stderr = function(_, d) append(d) end,
    on_exit = function(_, code)
      vim.schedule(function()
        if partial[1] ~= "" then append({ "", "" }) end
        M.jobs[title] = nil
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modifiable = true
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", ("[exit code %d]"):format(code) })
          vim.bo[buf].modifiable = false
        end
        if opts.quickfix ~= false then
          local qf = M.to_qf(all)
          vim.fn.setqflist({}, "r", { title = title, items = qf })
          if #qf > 0 then
            vim.notify(("%s: %d problem location(s) → <Space>xq"):format(title, #qf), vim.log.levels.WARN)
          end
        end
        if opts.on_exit then opts.on_exit(code, all) end
      end)
    end,
  })
  if id <= 0 then
    vim.notify("Could not start: " .. opts.cmd[1], vim.log.levels.ERROR)
    return
  end
  M.jobs[title] = id
  return id
end

--- Quickfix from whatever is in the current log panel (e.g. after following logs).
function M.qf_from_current()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "odoolog" then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].filetype == "odoolog" and vim.fn.bufwinid(b) ~= -1 then buf = b end
    end
  end
  local qf = M.to_qf(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  vim.fn.setqflist({}, "r", { title = "Odoo log", items = qf })
  vim.notify(#qf .. " location(s) in quickfix")
  if #qf > 0 then vim.cmd("copen") end
end

M.ns = ns
return M
