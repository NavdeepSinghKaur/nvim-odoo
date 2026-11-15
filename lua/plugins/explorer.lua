-- File explorers
--   neo-tree : VSCode-like side bar.  <Space>e or <C-b> toggle · <Space>E show current file
--              inside it: a add (end with / for a folder) · d delete · r rename · c copy · m move
--                         y copy name · H hidden files · / filter · . set as root · ? ALL keys
--   oil      : press "-" to edit the current folder like a text file (rename = edit the text,
--              delete = delete the line, then :w). Great to reorganise a module quickly.
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-mini/mini.icons" },
    keys = {
      { "<leader>e", "<Cmd>Neotree toggle<CR>", desc = "Explorer" },
      { "<C-b>", "<Cmd>Neotree toggle<CR>", desc = "Explorer" },
      { "<leader>E", "<Cmd>Neotree reveal<CR>", desc = "Show current file in explorer" },
      {
        "<leader>fe",
        function()
          local _, dir = require("odoo.paths").module_of()
          vim.cmd("Neotree dir=" .. vim.fn.fnameescape(dir or vim.fn.getcwd()))
        end,
        desc = "Explorer at current module",
      },
      { "<leader>ge", "<Cmd>Neotree git_status float<CR>", desc = "Changed files (git)" },
      { "<leader>be", "<Cmd>Neotree buffers float<CR>", desc = "Open files (tree)" },
    },
    init = function()
      -- VSCode-like: the folder tree is always open on the left when nvim starts
      -- (set vim.g.explorer_on_start = false in init.lua to disable; <C-b> toggles it anyway)
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("neotree_on_start", { clear = true }),
        callback = function()
          if vim.g.explorer_on_start == false or vim.o.diff or vim.o.columns < 110 then return end
          local ft = vim.bo.filetype
          if ft == "gitcommit" or ft == "gitrebase" then return end
          vim.schedule(function() vim.cmd("Neotree show") end) -- show without moving the cursor
        end,
      })
      -- `nvim some/folder` opens the explorer
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("neotree_start", { clear = true }),
        callback = function()
          local f = vim.fn.expand("%:p")
          if f ~= "" and vim.fn.isdirectory(f) == 1 then
            vim.api.nvim_del_augroup_by_name("neotree_start")
            require("neo-tree")
          end
        end,
      })
    end,
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      sources = { "filesystem", "buffers", "git_status" },
      source_selector = { winbar = true }, -- tabs: Files | Buffers | Git
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true }, -- highlight the file you are editing
        use_libuv_file_watcher = true,
        hijack_netrw_behavior = "open_current",
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { "__pycache__", ".git" },
          never_show = { ".DS_Store" },
        },
      },
      window = {
        width = 36,
        mappings = {
          ["<space>"] = "none", -- keep <Space> as the leader key
          ["l"] = "open",
          ["h"] = "close_node",
          ["Y"] = {
            function(state)
              local path = state.tree:get_node():get_id()
              vim.fn.setreg("+", path)
              vim.notify("Copied: " .. path)
            end,
            desc = "Copy full path",
          },
          ["O"] = {
            function(state) vim.ui.open(state.tree:get_node():get_id()) end,
            desc = "Open with system app",
          },
          ["P"] = { "toggle_preview", config = { use_float = true } },
        },
      },
      default_component_configs = {
        indent = { with_expanders = true },
        git_status = { symbols = { unstaged = "󰄱", staged = "󰱒" } },
      },
    },
  },

  {
    "stevearc/oil.nvim",
    lazy = false,
    keys = { { "-", "<Cmd>Oil<CR>", desc = "Edit parent folder (oil)" } },
    opts = {
      default_file_explorer = false, -- neo-tree handles `nvim folder`
      view_options = { show_hidden = true, is_always_hidden = function(n) return n == "__pycache__" or n == ".." end },
      float = { padding = 4 },
      keymaps = { ["q"] = "actions.close", ["<C-h>"] = false, ["<C-l>"] = false },
    },
  },
}
