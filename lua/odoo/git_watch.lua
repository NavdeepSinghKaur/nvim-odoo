-- odoo_ls can't watch files on Linux, so a `git checkout` / `git pull` made in lazygit or another
-- terminal is not seen. We check the commit of the workspace when nvim gets focus or a terminal
-- closes, and restart odoo_ls (and forget the picker scans) if it changed.
local settings = require("odoo.settings")
local M = {}

local last_head

local function check()
  vim.system({ "git", "-C", settings.workspace, "rev-parse", "HEAD" }, { text = true }, function(result)
    if result.code ~= 0 then return end
    local head = vim.trim(result.stdout)
    vim.schedule(function()
      if last_head and head ~= last_head and #vim.lsp.get_clients({ name = "odoo_ls" }) > 0 then
        vim.notify("Git commit changed → restarting odoo_ls")
        vim.cmd("silent! OdooLs restart")
        pcall(function() require("odoo.pickers").clear_cache() end)
      end
      last_head = head
    end)
  end)
end

function M.setup()
  check()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose" }, {
    group = vim.api.nvim_create_augroup("odoo_git_head", { clear = true }),
    callback = function() vim.defer_fn(check, 300) end,
  })
end

return M
