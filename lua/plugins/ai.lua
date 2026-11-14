-- Claude Code inside Neovim (https://github.com/coder/claudecode.nvim)
-- Needs the `claude` CLI: https://docs.anthropic.com/en/docs/claude-code
--
--  <Space>ac  open / close Claude (right side)       <Space>af  jump to it
--  <Space>ab  give Claude the current file            <Space>as  (visual) send the selection
--  Claude proposes a change as a diff:  <Space>aa accept   <Space>ad reject
--  Claude sees the file and selection you have open, like the VSCode extension.
return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSelectModel", "ClaudeCodeAdd", "ClaudeCodeSend",
      "ClaudeCodeTreeAdd", "ClaudeCodeStatus", "ClaudeCodeStart", "ClaudeCodeStop", "ClaudeCodeOpen",
      "ClaudeCodeClose", "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeCloseAllDiffs",
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
      { "<leader>as", "<Cmd>ClaudeCodeTreeAdd<CR>", desc = "Add file to Claude", ft = { "neo-tree", "oil", "snacks_picker_list" } },
      { "<leader>aa", "<Cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept Claude's diff" },
      { "<leader>ad", "<Cmd>ClaudeCodeDiffDeny<CR>", desc = "Reject Claude's diff" },
    },
  },
}
