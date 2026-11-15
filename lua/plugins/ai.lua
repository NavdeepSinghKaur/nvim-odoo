-- Claude Code inside Neovim (https://github.com/coder/claudecode.nvim)
-- Needs the `claude` CLI: https://docs.anthropic.com/en/docs/claude-code
--
--  <Space>ac  open / close Claude (right side)       <Space>af  jump to it
--  <Space>ab  give Claude the current file            <Space>as  (visual) send the selection
--  <Space>al  give Claude the output of the last Odoo update / test
--  <Space>ax  same, and type "find the cause and fix it" (you press Enter)
--  Claude proposes a change as a diff:  <Space>aa accept   <Space>ad reject
--  Claude sees the file, the selection and the diagnostics you have open, like the VSCode
--  extension. Review everything it changed with <Space>gd (diff view) and the hunk keys.
--  In its terminal Claude runs `odoo-nvim update/test ...` itself: see :Odoo ai-init.

--- Give Claude the log of the last update / install / test (local paths, tracebacks included).
---@return boolean added
local function add_last_run()
  local file = require("odoo.last_run").file()
  if vim.fn.filereadable(file) == 0 then
    vim.notify("No Odoo run yet: update or test a module first", vim.log.levels.WARN)
    return false
  end
  vim.cmd("ClaudeCodeAdd " .. vim.fn.fnameescape(file))
  return true
end

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSelectModel",
      "ClaudeCodeAdd",
      "ClaudeCodeSend",
      "ClaudeCodeSendText",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
      "ClaudeCodeStart",
      "ClaudeCodeStop",
      "ClaudeCodeOpen",
      "ClaudeCodeClose",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
      "ClaudeCodeCloseAllDiffs",
    },
    opts = {
      terminal = { split_side = "right", split_width_percentage = 0.38 },
    },
    keys = {
      { "<leader>ac", "<Cmd>ClaudeCode<CR>", desc = "Toggle Claude" },
      { "<C-,>", "<Cmd>ClaudeCodeFocus<CR>", desc = "Focus Claude", mode = { "n", "x", "t" } },
      { "<leader>af", "<Cmd>ClaudeCodeFocus<CR>", desc = "Focus Claude" },
      { "<leader>ar", "<Cmd>ClaudeCode --resume<CR>", desc = "Resume a past conversation" },
      { "<leader>aC", "<Cmd>ClaudeCode --continue<CR>", desc = "Continue last conversation" },
      { "<leader>am", "<Cmd>ClaudeCodeSelectModel<CR>", desc = "Select Claude model" },
      { "<leader>ab", "<Cmd>ClaudeCodeAdd %<CR>", desc = "Add current file to Claude" },
      { "<leader>as", "<Cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Send selection to Claude" },
      {
        "<leader>as",
        "<Cmd>ClaudeCodeTreeAdd<CR>",
        desc = "Add file to Claude",
        ft = { "neo-tree", "oil", "snacks_picker_list" },
      },
      { "<leader>al", add_last_run, desc = "Add last Odoo run (update / test output) to Claude" },
      {
        "<leader>ax",
        function()
          if not add_last_run() then return end
          -- the ! leaves the text in the prompt without sending it
          vim.cmd("ClaudeCodeSendText! The Odoo run in that log failed. Find the cause and fix it.")
        end,
        desc = "Ask Claude to fix the last Odoo run",
      },
      { "<leader>aa", "<Cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept Claude's diff" },
      { "<leader>ad", "<Cmd>ClaudeCodeDiffDeny<CR>", desc = "Reject Claude's diff" },
    },
  },
}
