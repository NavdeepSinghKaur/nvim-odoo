-- Look & feel: theme, statusline, tabs (bufferline), the <Space> menu (which-key)...
return {
  -- Theme. Try others with <Space>uC (catppuccin is installed too).
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night", styles = { comments = { italic = true } } },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },

  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- The menu that pops up when you press <Space> (or g, z, [, ], ", ' ...) and wait.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 300,
      spec = {
        { "<leader>a", group = "AI (Claude Code)" },
        { "<leader>b", group = "buffers (open files)" },
        { "<leader>c", group = "code (LSP)" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "find files" },
        { "<leader>g", group = "git" },
        { "<leader>gh", group = "hunks (changes)" },
        { "<leader>o", group = "ODOO" },
        { "<leader>q", group = "session / quit" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "terminal" },
        { "<leader>u", group = "toggles (UI)" },
        { "<leader>w", group = "windows" },
        { "<leader>x", group = "problems / quickfix" },
        { "g", group = "goto" },
        { "gs", group = "surround" },
        { "[", group = "previous" },
        { "]", group = "next" },
        { "z", group = "fold" },
      },
    },
    keys = {
      { "<leader>k", function() require("which-key").show({ global = false }) end, desc = "Shortcuts of this buffer" },
    },
  },

  -- Statusline (bottom bar)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        options = {
          theme = "auto",
          globalstatus = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "│", right = "│" },
          disabled_filetypes = { statusline = { "snacks_dashboard" } },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = {
            { "diagnostics" },
            { "filename", path = 1, symbols = { modified = " ●", readonly = " 󰌾" } },
            -- where am I: class › method  (or XML record › xpath)
            { function() return require("config.status").breadcrumb() end, color = "Comment" },
          },
          lualine_x = {
            -- "odoo_ls: Indexing… 45%" for ~15 s after startup
            { function() return require("config.status").lsp_progress() end, color = "DiagnosticInfo" },
            { function() return require("odoo").statusline() end, color = "DiagnosticWarn" },
            {
              function() return "  " .. require("dap").status() end,
              cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
              color = "DiagnosticError",
            },
            {
              function() return "󰒲 updates" end,
              cond = function() return require("lazy.status").has_updates() end,
              color = "Comment",
            },
            {
              function()
                local names = {}
                for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
                  table.insert(names, c.name)
                end
                return #names > 0 and (" " .. table.concat(names, " ")) or ""
              end,
              color = "Comment",
            },
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        extensions = { "neo-tree", "lazy", "quickfix", "trouble", "nvim-dap-ui" },
      }
    end,
  },

  -- Tabs on top, one per open file (click them, middle-click to close)
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Pin tab" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Close unpinned tabs" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Close tabs to the left" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Close tabs to the right" },
      { "<leader>bj", "<Cmd>BufferLinePick<CR>", desc = "Pick a tab by letter" },
      { "<A-h>", "<Cmd>BufferLineMovePrev<CR>", desc = "Move tab left" },
      { "<A-l>", "<Cmd>BufferLineMoveNext<CR>", desc = "Move tab right" },
    },
    opts = {
      options = {
        close_command = function(n) Snacks.bufdelete(n) end,
        right_mouse_command = function(n) Snacks.bufdelete(n) end,
        middle_mouse_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        separator_style = "thin",
        -- when two tabs have the same name (models/sale_order.py) show the module folder
        name_formatter = function(buf)
          local name = vim.fn.fnamemodify(buf.path, ":t")
          if name == "__manifest__.py" or name == "__init__.py" then
            return vim.fn.fnamemodify(buf.path, ":h:t") .. "/" .. name
          end
        end,
        offsets = {
          { filetype = "neo-tree", text = "Explorer", highlight = "Directory", text_align = "left" },
        },
      },
    },
  },

  -- Minimap on the right edge of each code window, like VSCode: <Space>um
  -- Off until you ask for it. Shows the code shape in colour, errors, git changes and search
  -- matches; click it to jump. To have it on at every start, set auto_enable = true below.
  {
    "Isrothy/neominimap.nvim",
    version = "v3.x.x",
    lazy = false, -- nothing heavy runs until the minimap is enabled
    init = function()
      local width = 18
      vim.g.neominimap = {
        auto_enable = false,
        layout = "float", -- one per window, so it never overlaps the Claude or explorer panels
        float = { minimap_width = width, window_border = "none" },
        -- panels, terminals and the log are skipped by their buffer type (the plugin default)
        exclude_filetypes = { "help", "bigfile", "snacks_dashboard" },
        click = { enabled = true, auto_switch_focus = false },
        search = { enabled = true },
      }
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          local code_margin = vim.o.sidescrolloff
          Snacks.toggle({
            name = "Minimap",
            get = function() return require("neominimap.api").enabled() end,
            set = function(on)
              local minimap = require("neominimap.api")
              if on then
                minimap.enable()
              else
                minimap.disable()
              end
              -- long lines scroll before the cursor goes under the minimap
              vim.o.sidescrolloff = on and (width + code_margin) or code_margin
            end,
          }):map("<leader>um")
        end,
      })
    end,
  },

  -- Nice rendering of Markdown (README, cheat sheet, docs/rag)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    opts = { code = { sign = false, width = "block", right_pad = 1 }, heading = { sign = false } },
  },

  -- TODO / FIXME / HACK highlighted, and listed with <Space>st
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      ---@diagnostic disable-next-line: undefined-field (added to Snacks by todo-comments)
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "TODO comments" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous TODO" },
    },
  },
}
