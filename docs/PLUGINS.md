# Plugins: what is installed, why, and what was considered

Every plugin is pinned in [`lazy-lock.json`](../lazy-lock.json), so an install gives the
versions this config was tested with. Stars and last activity are from GitHub on
2026-11-15; they are here to show how widely used and how alive each project is.

A few are stable but quiet: **diffview.nvim** (last change 2024-08), **vim-visual-multi**
(2024-09) and **bufferline.nvim** (2025-01) still work on Neovim 0.12; the usual replacement
is named in case one stops working.

## Core

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [folke/lazy.nvim](https://github.com/folke/lazy.nvim) | 21.7k | 2026-06 | plugin manager, lockfile, lazy loading | built-in `vim.pack` (Neovim 0.12) |
| [folke/snacks.nvim](https://github.com/folke/snacks.nvim) | 8.2k | 2026-05 | pickers, terminal, notifications, dashboard, toggles, big-file handling | telescope.nvim, fzf-lua |
| [folke/which-key.nvim](https://github.com/folke/which-key.nvim) | 7.3k | 2025-10 | the menu after `Space` | mini.clue |
| [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | 3.5k | 2026-04 | library used by neo-tree and diffview | - |
| [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim) | 2.1k | 2026-08 | UI library used by neo-tree | - |

## Code intelligence

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | 14.0k | 2026-11 | ready-made configs for the language servers | writing `vim.lsp.config` by hand |
| [odoo/odoo-neovim](https://github.com/odoo/odoo-neovim) | 27 | 2026-11 | official client of [odoo-ls](https://github.com/odoo/odoo-ls) (195 stars), Odoo SA's language server: models, fields, XML ids | pyright + odoo stubs (much less Odoo-aware) |
| [mason-org/mason.nvim](https://github.com/mason-org/mason.nvim) | 10.5k | 2026-06 | installs language servers, formatters, debugpy | system packages |
| [WhoIsSethDaniel/mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) | 760 | 2026-01 | keeps the tool list of `lua/config/tools.lua` installed | mason-lspconfig |
| [saghen/blink.cmp](https://github.com/saghen/blink.cmp) | 6.7k | 2026-11 | completion and snippets | nvim-cmp |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | 2.8k | 2026-11 | general snippets next to the Odoo ones in `snippets/` | - |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | 5.4k | 2026-08 | formatting (black for your own addons, StyLua) | none-ls |
| [folke/lazydev.nvim](https://github.com/folke/lazydev.nvim) | 1.6k | 2026-03 | Lua completion when editing this config | `.luarc.json` by hand |
| [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | 14.5k | 2026-11 | parsers for highlighting and indentation | regex syntax files |
| [nvim-treesitter/nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | 2.8k | 2026-09 | function / class / argument text objects | - |
| [nvim-treesitter/nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | 3.2k | 2026-10 | sticky class / def header (`Space uc`) | - |
| [windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag) | 2.1k | 2026-10 | closes and renames XML tags | - |

## Debugging

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap) | 7.3k | 2026-09 | debug adapter client (F5, F9, F10, F11) | - |
| [mfussenegger/nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python) | 716 | 2025-12 | debugpy setup | manual adapter config |
| [rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) | 3.4k | 2026-07 | variables, stack, watches panels | nvim-dap-view |
| [nvim-neotest/nvim-nio](https://github.com/nvim-neotest/nvim-nio) | 433 | 2026-07 | library used by nvim-dap-ui | - |
| [theHamsta/nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) | 1.1k | 2025-05 | variable values next to the code | - |
| [Weissle/persistent-breakpoints.nvim](https://github.com/Weissle/persistent-breakpoints.nvim) | 266 | 2025-03 | breakpoints survive a restart | - |

## Editing and navigation

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [folke/flash.nvim](https://github.com/folke/flash.nvim) | 4.3k | 2026-08 | jump anywhere with `s` | leap.nvim |
| [nvim-mini/mini.ai](https://github.com/nvim-mini/mini.ai), [mini.surround](https://github.com/nvim-mini/mini.surround), [mini.pairs](https://github.com/nvim-mini/mini.pairs), [mini.icons](https://github.com/nvim-mini/mini.icons) | 9.7k (mini.nvim) | 2026-11 | text objects, surround, auto pairs, icons | nvim-surround, nvim-autopairs, nvim-web-devicons |
| [NMAC427/guess-indent.nvim](https://github.com/NMAC427/guess-indent.nvim) | 670 | 2025-03 | uses the indentation of the file you open | vim-sleuth |
| [mg979/vim-visual-multi](https://github.com/mg979/vim-visual-multi) | 4.9k | 2024-09 | multiple cursors (`Ctrl+d`) | multicursor.nvim |
| [MagicDuck/grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim) | 2.0k | 2026-10 | search and replace across files | nvim-spectre |
| [folke/trouble.nvim](https://github.com/folke/trouble.nvim) | 6.9k | 2025-10 | problems / quickfix list | built-in quickfix |
| [folke/todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | 4.2k | 2025-11 | TODO / FIXME highlighted and listed | - |
| [folke/persistence.nvim](https://github.com/folke/persistence.nvim) | 1.0k | 2025-10 | sessions per folder | auto-session |

## Files and git

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | 5.7k | 2026-11 | file tree (`Ctrl+b`) | nvim-tree, snacks explorer |
| [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim) | 7.0k | 2026-10 | edit a folder like a buffer | mini.files |
| [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | 7.2k | 2026-11 | changed lines, hunks, blame | mini.diff |
| [sindrets/diffview.nvim](https://github.com/sindrets/diffview.nvim) | 5.9k | 2024-08 | review all changes, file history | codediff.nvim, `:DiffTool` |

## Look

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim), [catppuccin/nvim](https://github.com/catppuccin/nvim) | 8.3k, 7.7k | 2026-03, 2026-10 | colour schemes | any |
| [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | 8.2k | 2026-05 | status line | mini.statusline |
| [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim) | 4.4k | 2025-01 | tabs for open files | barbar.nvim |
| [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | 5.3k | 2026-11 | rendered Markdown (cheat sheet, docs) | markview.nvim |
| [Isrothy/neominimap.nvim](https://github.com/Isrothy/neominimap.nvim) | 384 | 2026-04 | minimap (`Space um`), see below | see below |

## AI

| Plugin | Stars | Last change | What it does here | Alternative |
|---|---:|---|---|---|
| [coder/claudecode.nvim](https://github.com/coder/claudecode.nvim) | 3.2k | 2026-11 | Claude Code in a panel, connected to the editor like the VSCode extension | see [AI.md](AI.md) |

## Minimap: what was compared

Minimap plugins are a small niche in Neovim, so none has the numbers of the plugins above.

| Plugin | Stars | Last change | Notes |
|---|---:|---|---|
| **[Isrothy/neominimap.nvim](https://github.com/Isrothy/neominimap.nvim)** (chosen) | 384 | 2026-04 | Closest to VSCode: Treesitter colours, diagnostics, git, search, folds, mouse click to jump. Pure Lua, renders only when the text changes. MIT. |
| [nvim-mini/mini.map](https://github.com/nvim-mini/mini.map) | 9.7k as part of mini.nvim (133 standalone) | 2026-11 | The most trusted author and the most actively maintained. One colour, keyboard-first, no click. The safe fallback: this config already uses four mini modules. |
| [wfxr/minimap.vim](https://github.com/wfxr/minimap.vim) | 1.3k | 2026-07 | Most stars, but needs the external `code-minimap` program (Rust) and has no syntax colours. |
| [gorbit99/codewindow.nvim](https://github.com/gorbit99/codewindow.nvim) | 489 | 2025-05 | The project that inspired neominimap; redraws on every focus change, quiet since 2025. |
| [lewis6991/satellite.nvim](https://github.com/lewis6991/satellite.nvim) | 754 | 2026-11 | A scrollbar with marks, not a minimap. Good if you only want "where are the errors". |

To switch to mini.map, replace the neominimap entry in `lua/plugins/ui.lua` with:

```lua
{
  "nvim-mini/mini.map",
  keys = { { "<leader>um", function() require("mini.map").toggle() end, desc = "Toggle minimap" } },
  opts = function()
    local map = require("mini.map")
    return { integrations = { map.gen_integration.builtin_search(), map.gen_integration.diagnostic(), map.gen_integration.gitsigns() } }
  end,
}
```

## AI and MCP: what was considered and left out

| Project | Stars | What it is | Why not installed |
|---|---:|---|---|
| [olimorris/codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) | 6.9k | chat and inline edits in Neovim buffers, many providers | a second assistant next to Claude Code |
| [avante-corp/avante.nvim](https://github.com/avante-corp/avante.nvim) | 18.2k | Cursor-like sidebar | same |
| [folke/sidekick.nvim](https://github.com/folke/sidekick.nvim) | 2.8k | Copilot next-edit suggestions and CLI agents in a terminal | needs a Copilot subscription; worth a look if you have one |
| [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) | 4.1k | inline completion | optional, can be added as a blink.cmp source |
| [ravitemer/mcphub.nvim](https://github.com/ravitemer/mcphub.nvim) | 1.8k | MCP client: gives MCP tools to codecompanion / avante | not needed: Claude Code has its own MCP support |
| [bigcodegen/mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) | 325 | MCP server that controls a running Neovim | duplicates what claudecode.nvim provides, and can run any editor command |

Development tools (not plugins): [StyLua](https://github.com/JohnnyMorganz/StyLua),
[selene](https://github.com/Kampfkarren/selene),
[lua-language-server](https://github.com/LuaLS/lua-language-server) and
[mini.test](https://github.com/nvim-mini/mini.test). See [CONTRIBUTING](../README.md#contributing).
