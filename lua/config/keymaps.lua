-- General shortcuts. Plugin shortcuts live next to each plugin in lua/plugins/*.lua.
-- Tip: press <Space> and wait to see everything, or <Space>sk to search all shortcuts.
local map = function(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { desc = desc, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- ---------------------------------------------------------------- VSCode habits
map({ "n", "i", "x" }, "<C-s>", "<Cmd>w<CR><Esc>", "Save file")
map("n", "<C-q>", "<Cmd>qa<CR>", "Quit Neovim (asks to save)")
map("n", "<C-a>", "ggVG", "Select all")
map("n", "<A-j>", "<Cmd>m .+1<CR>==", "Move line down")
map("n", "<A-k>", "<Cmd>m .-2<CR>==", "Move line up")
map("i", "<A-j>", "<Esc><Cmd>m .+1<CR>==gi", "Move line down")
map("i", "<A-k>", "<Esc><Cmd>m .-2<CR>==gi", "Move line up")
map("x", "<A-j>", ":m '>+1<CR>gv=gv", "Move selection down")
map("x", "<A-k>", ":m '<-2<CR>gv=gv", "Move selection up")
map("n", "<A-Down>", "<Cmd>m .+1<CR>==", "Move line down")
map("n", "<A-Up>", "<Cmd>m .-2<CR>==", "Move line up")
map("x", "<A-Down>", ":m '>+1<CR>gv=gv", "Move selection down")
map("x", "<A-Up>", ":m '<-2<CR>gv=gv", "Move selection up")
map("n", "<C-/>", "gcc", "Toggle comment", { remap = true })
map("x", "<C-/>", "gc", "Toggle comment", { remap = true })
map("n", "<C-_>", "gcc", "which_key_ignore", { remap = true }) -- some terminals send C-_ for C-/
map("x", "<C-_>", "gc", "which_key_ignore", { remap = true })

-- Keep the selection when indenting with < and >
map("x", "<", "<gv", "Indent left")
map("x", ">", ">gv", "Indent right")
map("x", "<Tab>", ">gv", "Indent right")
map("x", "<S-Tab>", "<gv", "Indent left")

-- Paste over a selection without losing what you copied
map("x", "p", '"_dP', "Paste (keep clipboard)")

-- Escape clears search highlight
map({ "n", "i" }, "<Esc>", "<Cmd>nohlsearch<CR><Esc>", "Clear search highlight")

-- Move by visual line when lines wrap
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })

-- Centre the screen after jumps/searches
map("n", "<C-d>", "<C-d>zz", "Half page down")
map("n", "<C-u>", "<C-u>zz", "Half page up")
map("n", "n", "nzzzv", "Next match")
map("n", "N", "Nzzzv", "Previous match")

-- ---------------------------------------------------------------- Windows / splits
map("n", "<C-h>", "<C-w>h", "Go to left window")
map("n", "<C-j>", "<C-w>j", "Go to lower window")
map("n", "<C-k>", "<C-w>k", "Go to upper window")
map("n", "<C-l>", "<C-w>l", "Go to right window")
map("n", "<C-Up>", "<Cmd>resize +2<CR>", "Taller window")
map("n", "<C-Down>", "<Cmd>resize -2<CR>", "Shorter window")
map("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", "Narrower window")
map("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", "Wider window")
map("n", "<leader>w|", "<C-w>v", "Split right")
map("n", "<leader>w-", "<C-w>s", "Split below")
map("n", "<leader>wd", "<C-w>c", "Close window")
map("n", "<leader>wo", "<C-w>o", "Close other windows")
map("n", "<leader>w=", "<C-w>=", "Equalize sizes")
map("n", "<leader>|", "<C-w>v", "Split right")
map("n", "<leader>-", "<C-w>s", "Split below")

-- ---------------------------------------------------------------- Buffers (= open files / tabs)
map("n", "<S-h>", "<Cmd>bprevious<CR>", "Previous tab")
map("n", "<S-l>", "<Cmd>bnext<CR>", "Next tab")
map("n", "[b", "<Cmd>bprevious<CR>", "Previous buffer")
map("n", "]b", "<Cmd>bnext<CR>", "Next buffer")
map("n", "<leader>bb", "<Cmd>e #<CR>", "Switch to last buffer")
map("n", "<leader>`", "<Cmd>e #<CR>", "Switch to last buffer")

-- ---------------------------------------------------------------- Diagnostics / quickfix
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next problem")
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous problem")
map("n", "]e", function()
  vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.ERROR })
end, "Next error")
map("n", "[e", function()
  vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.ERROR })
end, "Previous error")
map("n", "<leader>cd", vim.diagnostic.open_float, "Show problem under cursor")
map("n", "]q", "<Cmd>cnext<CR>zz", "Next quickfix item")
map("n", "[q", "<Cmd>cprev<CR>zz", "Previous quickfix item")

-- ---------------------------------------------------------------- Misc
map("n", "<leader>qq", "<Cmd>qa<CR>", "Quit all")
map("n", "<leader>fn", "<Cmd>enew<CR>", "New empty file")
map("n", "<leader>fy", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, "Copy file path")
map("n", "<leader>fY", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, "Copy relative file path")
map("n", "<leader>un", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, "Toggle relative numbers")
map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, "Toggle line wrap")
map("n", "<leader>l", "<Cmd>Lazy<CR>", "Plugin manager (Lazy)")
map("n", "<leader>?", function() require("odoo").cheatsheet() end, "Cheat sheet")

-- Neovim 0.11+ ships gr* defaults (grr, grn, gra...). We use our own gr / gd / <Space>c* below,
-- so remove them to avoid a delay when pressing "gr".
for _, lhs in ipairs({ "grr", "grn", "gra", "gri", "grt", "grx" }) do
  pcall(vim.keymap.del, "n", lhs)
end
pcall(vim.keymap.del, "x", "gra")
