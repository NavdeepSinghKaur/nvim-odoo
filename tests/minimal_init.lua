-- Minimal Neovim for the tests: this repo + mini.test on the runtimepath, no plugins, no user data.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/deps/mini.test")
vim.o.swapfile = false
require("mini.test").setup()
