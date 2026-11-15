-- What the config installs by itself, in one place: the editor installs these in the
-- background (lua/plugins/lsp.lua, lua/plugins/treesitter.lua) and scripts/bootstrap.lua
-- installs them up front for an unattended setup.
local M = {}

-- Language servers, formatters, linters and the debug adapter (:Mason)
-- stylua: ignore
M.mason = {
  "basedpyright", "ruff", "lemminx", "lua-language-server", "json-lsp", "yaml-language-server",
  "css-lsp", "typescript-language-server", "black", "stylua", "debugpy", "selene",
}

-- Treesitter parsers (need the tree-sitter CLI and a C compiler)
-- stylua: ignore
M.parsers = {
  "python", "xml", "html", "javascript", "typescript", "css", "scss", "json", "yaml", "toml",
  "lua", "luadoc", "vim", "vimdoc", "query", "markdown", "markdown_inline", "bash", "sql", "csv",
  "po", "rst", "regex", "diff", "gitcommit", "git_rebase", "gitignore", "dockerfile", "ini",
}

return M
