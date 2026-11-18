-- Editor options. `:help 'option'` explains any of them, e.g. `:help 'relativenumber'`.
local opt = vim.opt

-- Look
opt.number = true -- line numbers
opt.relativenumber = false -- plain numbers like VSCode. <Space>un toggles relative numbers (handy for "5j")
opt.cursorline = true -- highlight current line
opt.signcolumn = "yes" -- always show the column for git / errors / breakpoints
opt.colorcolumn = "100" -- black + flake8 at 100 chars (OCA style is 88: change here + format.lua)
opt.termguicolors = true
opt.scrolloff = 8 -- keep 8 lines visible above/below the cursor
opt.sidescrolloff = 8
opt.wrap = false
opt.list = true -- show tabs and trailing spaces
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.showmode = false -- the statusline already shows the mode
opt.laststatus = 3 -- one global statusline
opt.pumheight = 12
opt.winborder = "rounded" -- rounded borders on floating windows (hover, signature...)
opt.fillchars = { eob = " ", diff = "╱" }
opt.splitright = true -- vertical splits open to the right
opt.splitbelow = true -- horizontal splits open below

-- Behaviour
opt.mouse = "a" -- the mouse works everywhere (click, scroll, resize, select)
opt.mousescroll = "ver:3,hor:6" -- lines per mouse-wheel step
opt.clipboard = "unnamedplus" -- yank/paste use the system clipboard (like Ctrl+C / Ctrl+V)
opt.undofile = true -- undo history survives closing the file
opt.swapfile = false
opt.confirm = true -- ask to save instead of failing on :q with changes
opt.updatetime = 250
opt.timeoutlen = 400 -- how long to wait for the next key of a shortcut
opt.virtualedit = "block"
opt.inccommand = "split" -- live preview of :%s/old/new/
opt.jumpoptions = "view"
opt.completeopt = "menu,menuone,noselect"
opt.shortmess:append("sI")

-- Search
opt.ignorecase = true -- case-insensitive search ...
opt.smartcase = true -- ... unless you type a capital letter
opt.grepprg = "rg --vimgrep --smart-case"

-- Indentation (Odoo: 4 spaces in Python and XML)
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.shiftround = true

-- Folding with treesitter (za toggles a fold, zR opens all, zM closes all)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99 -- start with everything open
opt.foldtext = ""

-- Sessions (persistence.nvim restores your open files per folder)
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

-- Odoo-ish filetypes
vim.filetype.add({
  extension = { po = "po", pot = "po" },
  filename = { ["odools.toml"] = "toml" },
})
