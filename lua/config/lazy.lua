-- lazy.nvim = the plugin manager. `:Lazy` opens its UI (update with U, sync with S).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n" .. out, "ErrorMsg" } }, true, {})
    return
  end
  -- Pin the fresh clone to the commit of lazy-lock.json: `stable` is newer, and lazy would
  -- then rewrite the lockfile (a dirty repo after every install).
  local ok, lock = pcall(
    function() return vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"))) end
  )
  local commit = ok and type(lock) == "table" and type(lock["lazy.nvim"]) == "table" and lock["lazy.nvim"].commit
  if commit then vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", commit }) end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } }, -- every file in lua/plugins/ is loaded
  install = { colorscheme = { "tokyonight", "habamax" } },
  -- check for plugin updates silently once a day (shown in the statusline)
  checker = { enabled = true, notify = false, frequency = 86400 },
  change_detection = { notify = false },
  rocks = { enabled = false }, -- no plugin here needs luarocks
  ui = { border = "rounded" },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "zipPlugin", "netrwPlugin" },
    },
  },
})
