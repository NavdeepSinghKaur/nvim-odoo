-- Autocompletion + snippets (blink.cmp)
--   The menu opens while typing.  <CR> or <Tab> accept · <C-n>/<C-p> or ↓/↑ move
--   <C-space> open menu / docs · <C-e> close · after a snippet: <Tab> / <S-Tab> jump between fields
--
-- Odoo snippets: nvim/snippets/*.json (VSCode format). Type "o" + what you want:
--   omodel, oinherit, ofchar, ofm2o, ocompute, oform, olist, oxpath, oaction, omenu, otest...
--   Type "o" and look at the menu, or open the files to see them all.
return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- downloads a prebuilt fuzzy matcher
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        documentation = { auto_show = true, auto_show_delay_ms = 200, window = { border = "rounded" } },
        menu = {
          border = "rounded",
          draw = {
            treesitter = { "lsp" },
            columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
          },
        },
        ghost_text = { enabled = true }, -- grey preview of the selected item
        accept = { auto_brackets = { enabled = true } },
      },
      signature = { enabled = true, window = { border = "rounded" } }, -- function arguments while typing
      snippets = { preset = "default" }, -- loads nvim/snippets + friendly-snippets
      sources = {
        default = { "lazydev", "lsp", "snippets", "path", "buffer" },
        per_filetype = { lua = { inherit_defaults = true, "lazydev" } },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          snippets = { score_offset = 5 }, -- Odoo snippets show up high
        },
      },
      cmdline = { keymap = { preset = "cmdline" }, completion = { menu = { auto_show = true } } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
}
