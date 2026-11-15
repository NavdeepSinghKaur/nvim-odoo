-- Prints the lua-language-server config used by `make typecheck`.
-- Usage: nvim -u NONE -l scripts/luarc.lua <lazy plugin dir>
local lazy_dir = arg[1]
local config = {
  runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
  workspace = {
    checkThirdParty = false,
    ignoreDir = { "deps", ".cache" },
    library = {
      vim.env.VIMRUNTIME .. "/lua",
      lazy_dir .. "/snacks.nvim/lua",
      lazy_dir .. "/lazy.nvim/lua",
      lazy_dir .. "/blink.cmp/lua",
      "deps/mini.test/lua",
    },
  },
  diagnostics = { globals = { "vim", "Snacks", "MiniTest" } },
}
io.write(vim.json.encode(config), "\n")
