-- Automatic actions.
local group = vim.api.nvim_create_augroup("user_config", { clear = true })
local au = function(event, opts)
  opts.group = group
  vim.api.nvim_create_autocmd(event, opts)
end

-- Briefly highlight what you yank (copy)
au("TextYankPost", { callback = function() vim.hl.on_yank({ timeout = 200 }) end })

-- Re-open files at the last cursor position
au("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lines = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lines and vim.bo[ev.buf].filetype ~= "gitcommit" then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Reload files changed outside nvim (git checkout, another editor...)
au({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end
  end,
})

-- Resize splits when the terminal window is resized
au("VimResized", { callback = function() vim.cmd("tabdo wincmd =") end })

-- Close helper windows with q
au("FileType", {
  pattern = { "help", "qf", "lspinfo", "checkhealth", "man", "notify", "grug-far", "dap-float", "odoolog" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = ev.buf, silent = true, desc = "Close" })
  end,
})

-- Per-filetype indentation
au("FileType", {
  pattern = { "lua", "json", "jsonc", "yaml", "markdown", "scss", "css" },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- Wrap + spell check in prose files
au("FileType", {
  pattern = { "markdown", "gitcommit", "text", "rst" },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
  end,
})

-- Create missing folders when saving a new file (e.g. models/new_file.py in a new module)
au("BufWritePre", {
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then return end
    local file = (vim.uv or vim.loop).fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Make read-only the Odoo core copy and OCA/third-party code: you browse it, you don't edit it.
au("BufReadPost", {
  callback = function(ev)
    local ok, odoo = pcall(require, "odoo")
    if ok and odoo.is_readonly_path(vim.api.nvim_buf_get_name(ev.buf)) then
      vim.bo[ev.buf].modifiable = true -- still allow temporary edits for experiments...
      vim.bo[ev.buf].readonly = true -- ...but warn before saving
    end
  end,
})
