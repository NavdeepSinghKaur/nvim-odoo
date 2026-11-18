local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["Mason installs the tree-sitter CLI, not npm packages"] = function()
  local tools = require("config.tools")
  eq(vim.tbl_contains(tools.mason, "tree-sitter-cli"), true)
  for _, npm_server in ipairs({ "json-lsp", "yaml-language-server", "css-lsp", "typescript-language-server" }) do
    eq(vim.tbl_contains(tools.mason, npm_server), false)
  end
end

return T
