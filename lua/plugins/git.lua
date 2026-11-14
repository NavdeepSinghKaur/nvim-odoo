-- Git
--   Left column shows added / changed / deleted lines.
--   ]h [h next/prev change · <Space>ghp preview · <Space>ghs stage · <Space>ghr undo change
--   <Space>gb blame line · <Space>gd diff view (all changes) · <Space>gH file history
--   <Space>gg lazygit (full git UI: stage, commit, push, branches... press ? inside)
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = false,
      current_line_blame_opts = { delay = 400 },
      on_attach = function(buf)
        local gs = require("gitsigns")
        local map = function(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = buf, desc = desc }) end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next change")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Previous change")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview change")
        map({ "n", "x" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage change")
        map({ "n", "x" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Undo change (reset hunk)")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage whole file")
        map("n", "<leader>ghR", gs.reset_buffer, "Undo all changes in file")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame this line")
        map("n", "<leader>gA", gs.blame, "Blame whole file")
        map("n", "<leader>ub", gs.toggle_current_line_blame, "Toggle inline blame")
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select change")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<Cmd>DiffviewOpen<CR>", desc = "Diff view (all changes)" },
      { "<leader>gD", "<Cmd>DiffviewOpen origin/18.0_staging...HEAD<CR>", desc = "Diff my branch vs 18.0_staging" },
      { "<leader>gH", "<Cmd>DiffviewFileHistory %<CR>", desc = "History of this file" },
      { "<leader>gq", "<Cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    opts = { enhanced_diff_hl = true },
  },
}
