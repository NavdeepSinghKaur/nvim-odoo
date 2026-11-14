-- Editing helpers
return {
  -- Jump anywhere on screen: press s, type 2 letters, press the label that appears
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = { modes = { search = { enabled = false } } },
    keys = {
      { "s", function() require("flash").jump() end, mode = { "n", "x", "o" }, desc = "Jump (flash)" },
      { "S", function() require("flash").treesitter() end, mode = { "n", "x", "o" }, desc = "Select code block" },
    },
  },

  -- Surround: gsa" (add quotes around a selection/motion), gsd" (delete), gsr"' (replace " by ')
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = { add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF", highlight = "gsh", replace = "gsr", update_n_lines = "gsn" },
    },
  },

  -- Auto-close brackets and quotes
  { "nvim-mini/mini.pairs", event = "InsertEnter", opts = { modes = { insert = true, command = false } } },

  -- Detect 2 vs 4 spaces automatically per file
  { "NMAC427/guess-indent.nvim", event = "BufReadPre", opts = {} },

  -- Problems panel (like VSCode "Problems")
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<Cmd>Trouble diagnostics toggle<CR>", desc = "Problems (all files)" },
      { "<leader>xX", "<Cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Problems (this file)" },
      { "<leader>xq", "<Cmd>Trouble qflist toggle<CR>", desc = "Quickfix list (Odoo errors land here)" },
      { "<leader>xl", "<Cmd>Trouble loclist toggle<CR>", desc = "Location list" },
      { "<leader>cS", "<Cmd>Trouble symbols toggle<CR>", desc = "Outline (classes/methods) side bar" },
      { "<leader>xr", "<Cmd>Trouble lsp toggle<CR>", desc = "Definitions/references side bar" },
    },
  },

  -- Search & replace across files (VSCode "Search" panel)
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { headerMaxWidth = 80 },
    keys = {
      { "<leader>sR", function() require("grug-far").open() end, desc = "Search & replace in files", mode = { "n", "x" } },
      { "<leader>sM", function()
        local _, dir = require("odoo.paths").module_of()
        require("grug-far").open({ prefills = { paths = dir or vim.fn.getcwd() } })
      end, desc = "Search & replace in this module" },
    },
  },

  -- Sessions: reopens the files you had open in this folder
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this folder)" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Pick a session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save this session" },
    },
  },

  -- Multiple cursors like VSCode Ctrl+D:  <C-n> add next match · Ctrl+Alt+↓/↑ add cursor below/above
  -- (in multi-cursor mode: n/N skip, q remove, <Esc> exit)
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "VeryLazy",
    init = function()
      vim.g.VM_maps = { ["Find Under"] = "<C-n>", ["Find Subword Under"] = "<C-n>",
        ["Add Cursor Down"] = "<M-C-Down>", ["Add Cursor Up"] = "<M-C-Up>" }
      vim.g.VM_show_warnings = 0
    end,
  },
}
