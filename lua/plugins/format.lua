-- Formatting (conform.nvim)
--   On save: ONLY Python files of your own addons (settings.own_addons) are formatted, with black
--   and the repo's pyproject.toml (line length 100) = exactly what pre-commit does.
--   OCA / third-party / Odoo core are never touched. XML is never formatted on save
--   (it would create huge diffs); format a selection by hand with <Space>cf if you want.
--   <Space>uf toggles format-on-save.
return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "x" },
        desc = "Format file / selection",
      },
      {
        "<leader>uf",
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("Format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
        end,
        desc = "Toggle format on save",
      },
    },
    opts = {
      formatters_by_ft = {
        python = { "black" },
        lua = { "stylua" },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat then return end
        local name = vim.api.nvim_buf_get_name(bufnr)
        local ft = vim.bo[bufnr].filetype
        local odoo_paths = require("odoo.paths")
        if ft == "python" and odoo_paths.is_own(name) then return { timeout_ms = 3000, lsp_format = "never" } end
        if ft == "lua" and name:find(vim.fn.stdpath("config"), 1, true) then return { timeout_ms = 2000 } end
      end,
    },
  },
}
