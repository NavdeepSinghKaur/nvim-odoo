-- snacks.nvim: fuzzy finder (picker), start dashboard, terminal, lazygit, notifications...
-- Inside a picker: type to filter · <C-j>/<C-k> move · <CR> open · <C-v> vsplit · <C-s> split
--                  <Tab> select several · <C-q> send to quickfix · <Esc> close · ? help
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },   -- huge files (big .po / minified JS) open fast
    quickfile = { enabled = true },
    input = { enabled = true },     -- nicer text prompts
    notifier = { enabled = true, timeout = 4000 },
    indent = { enabled = true },    -- indentation guides
    scope = { enabled = true },
    words = { enabled = true },     -- highlights other uses of the word under cursor
    statuscolumn = { enabled = true },
    scroll = { enabled = false },
    lazygit = { configure = true },
    terminal = { win = { position = "bottom", height = 0.35 } },
    picker = {
      enabled = true,
      ui_select = true, -- every "choose one" menu uses the picker
      layout = { preset = "default" },
      formatters = { file = { filename_first = true, truncate = 80 } },
      sources = {
        files = { hidden = true },
        grep = { hidden = true },
        projects = {
          dev = require("odoo.settings").addons_paths, -- repos inside your addons folders
          patterns = { ".git", "__manifest__.py", "docker-compose.yml" },
        },
      },
    },
    dashboard = {
      enabled = true,
      preset = {
        header = [[
   ██████╗ ██████╗  ██████╗  ██████╗     ███╗   ██╗██╗   ██╗██╗███╗   ███╗
  ██╔═══██╗██╔══██╗██╔═══██╗██╔═══██╗    ████╗  ██║██║   ██║██║████╗ ████║
  ██║   ██║██║  ██║██║   ██║██║   ██║    ██╔██╗ ██║██║   ██║██║██╔████╔██║
  ██║   ██║██║  ██║██║   ██║██║   ██║    ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
  ╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝    ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
   ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝     ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
                 Odoo 18 · press <Space> and wait for the menu]],
        keys = {
          { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.picker.files()" },
          { icon = " ", key = "r", desc = "Recent files", action = ":lua Snacks.picker.recent()" },
          { icon = " ", key = "g", desc = "Search text (grep)", action = ":lua Snacks.picker.grep()" },
          { icon = "󰆧 ", key = "m", desc = "Find Odoo model", action = ":lua require('odoo.pickers').models()" },
          { icon = " ", key = "o", desc = "Find Odoo module", action = ":lua require('odoo.pickers').modules()" },
          { icon = " ", key = "e", desc = "File explorer", action = ":Neotree" },
          { icon = " ", key = "p", desc = "Projects / folders", action = ":lua Snacks.picker.projects()" },
          { icon = " ", key = "d", desc = "Debug Odoo", action = ":Odoo debug" },
          { icon = " ", key = "s", desc = "Restore last session", action = ":lua require('persistence').load()" },
          { icon = " ", key = "?", desc = "Cheat sheet", action = ":lua require('odoo').cheatsheet()" },
          { icon = "󰒲 ", key = "L", desc = "Plugins (Lazy)", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 0, padding = 1 },
        { icon = " ", title = "Recent files (this folder)", section = "recent_files", cwd = true, indent = 2, padding = 1 },
        { section = "startup" },
      },
    },
  },
  keys = {
    -- most used
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Find file (smart)" },
    { "<C-p>", function() Snacks.picker.files() end, desc = "Find file" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Search text in folder" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Open files (buffers)" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command history" },
    -- find
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Files" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Git files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects / folders" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Neovim config files" },
    -- search
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep (text in files)" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Word under cursor", mode = { "n", "x" } },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Lines in this file" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep open files" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Search ALL shortcuts" },
    { "<leader>sc", function() Snacks.picker.commands() end, desc = "Commands" },
    { "<leader>sd", function() Snacks.picker.diagnostics_buffer() end, desc = "Problems (this file)" },
    { "<leader>sD", function() Snacks.picker.diagnostics() end, desc = "Problems (all)" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Symbols (classes/methods/fields)" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Symbols in workspace" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jump list" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix list" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo history" },
    { "<leader>s\"", function() Snacks.picker.registers() end, desc = "Registers (clipboard history)" },
    { "<leader>sr", function() Snacks.picker.resume() end, desc = "Resume last search" },
    { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notification history" },
    { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
    -- git
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit (full git UI)" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git log of this file" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git stash" },
    { "<leader>gB", function() Snacks.picker.git_branches() end, desc = "Git branches" },
    { "<leader>go", function() Snacks.gitbrowse() end, desc = "Open on GitHub", mode = { "n", "v" } },
    -- terminal
    { "<C-\\>", function() Snacks.terminal.toggle() end, desc = "Toggle terminal", mode = { "n", "t" } },
    { "<leader>tt", function() Snacks.terminal.toggle() end, desc = "Terminal (bottom)" },
    { "<leader>tf", function() Snacks.terminal.toggle(nil, { win = { position = "float" } }) end, desc = "Terminal (float)" },
    -- misc
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Close this file" },
    { "<leader>bo", function() Snacks.bufdelete.other() end, desc = "Close other files" },
    { "<leader>uN", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
    { "<leader>z", function() Snacks.zen() end, desc = "Zen mode (focus)" },
    { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next reference", mode = { "n", "t" } },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev reference", mode = { "n", "t" } },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- handy toggles under <Space>u
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.dim():map("<leader>uD")
        Snacks.toggle.line_number():map("<leader>ul")
      end,
    })
  end,
}
