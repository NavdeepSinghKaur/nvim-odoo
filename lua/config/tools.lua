-- What the config installs by itself, in one place: the editor installs these in the
-- background (lua/plugins/lsp.lua, lua/plugins/treesitter.lua) and scripts/bootstrap.lua
-- installs them up front for an unattended setup.
local M = {}

-- Language servers, formatters, linters, the debug adapter and the tree-sitter CLI (:Mason).
-- The tree-sitter CLI is a prebuilt binary from Mason: no Node.js or npm is needed.
-- stylua: ignore
M.mason = {
  "basedpyright", "ruff", "lemminx", "lua-language-server", "black", "stylua", "debugpy", "selene",
  "tree-sitter-cli",
}

-- Treesitter parsers. Mason installs the tree-sitter CLI (above), but compiling a parser also
-- needs a C compiler on the system.
-- stylua: ignore
M.parsers = {
  "python", "xml", "html", "javascript", "typescript", "css", "scss", "json", "yaml", "toml",
  "lua", "luadoc", "vim", "vimdoc", "query", "markdown", "markdown_inline", "bash", "sql", "csv",
  "po", "rst", "regex", "diff", "gitcommit", "git_rebase", "gitignore", "dockerfile", "ini",
}

return M
