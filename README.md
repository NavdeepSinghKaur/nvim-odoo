# nvim-odoo

A complete Neovim setup for **Odoo development with Docker**, made for people coming from VSCode.
Everything is discoverable: press `Space` and a menu shows every shortcut; `Space ?` opens the
[cheat sheet](CHEATSHEET.md).

## What you get

- **Odoo-aware code intelligence** with [odoo-ls](https://github.com/odoo/odoo-ls) (Odoo's official
  language server): go to definition on models, fields, `_inherit`, `env["..."]`, XML ids; hover; completion.
- **Odoo commands under `Space o`**: update / install the current module, restart, follow the log,
  run the tests of the module or the test under the cursor, Odoo shell, psql, pick the database.
- **Log panel with clickable tracebacks**: container paths are translated to your local files,
  and traceback locations go to the quickfix list (your own code first).
- **Debugger like VSCode** (`F5`, `F9`, `F10`, `F11`): starts Odoo under debugpy with a generated
  compose override (your `docker-compose.yml` is never touched) and attaches, with breakpoints in
  your code and in Odoo core.
- **Odoo pickers**: find a model (definition and every `_inherit`), an XML id, the views of a model,
  a module; grep in one module, in core, or in every addons folder.
- **100+ snippets** for models, fields, views, security, OWL components, tests.
- **Claude Code** in a side panel (`Space a`) through [claudecode.nvim](https://github.com/coder/claudecode.nvim).
- VSCode-like keys (`Ctrl+s`, `Ctrl+p`, `Ctrl+b`, `Ctrl+/`, `F2`, `F12`), file tree, tabs, git
  (lazygit, gitsigns, diffview), format on save with black for your own code only.

## Requirements

- Neovim **0.11+** (developed on 0.12), git, a C compiler, `curl`, `unzip`
- [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd)
- `tree-sitter` CLI and Node.js (parsers and some language servers)
- Python 3 (runs the small odoo-ls proxy)
- A [Nerd Font](https://www.nerdfonts.com) selected in your terminal (for the icons)
- Docker with the compose plugin, and `debugpy` installed in your Odoo image for debugging
- Optional: [lazygit](https://github.com/jesseduffield/lazygit), the
  [`claude` CLI](https://docs.anthropic.com/en/docs/claude-code)

## Install

```bash
# back up an existing config first:  mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/NavdeepSinghKaur/nvim-odoo ~/.config/nvim
~/.config/nvim/scripts/install-odoo-ls.sh     # odoo-ls into ~/.local (no sudo)
nvim                                          # plugins and tools install themselves on first start
```

## Configure (2 minutes)

In Neovim run **`:Odoo config`**. It creates `lua/odoo/local.lua` (git-ignored) from
[`local.example.lua`](lua/odoo/local.example.lua). Set your folders there:

```lua
local root = "~/odoo"
return {
  workspace = root .. "/my-addons",                 -- the repo you work in
  own_addons = { root .. "/my-addons/custom" },     -- code you write
  addons_paths = { root .. "/my-addons/custom", root .. "/my-addons/oca" },
  readonly_paths = { root .. "/my-addons/oca" },    -- code you only read
  compose_dir = root .. "/docker",                  -- folder with docker-compose.yml
  service = "odoo",                                 -- odoo service name in it
  db_service = "db",
}
```

Restart Neovim, then:

1. `:Odoo info` (`Space o ?`) shows what is used: container, database, folders.
2. `:Odoo sync-core` copies the Odoo source out of your container/image, so go-to-definition and
   the debugger can open core files. Not needed if you set `core` to an Odoo source checkout.
3. Open a Python file of one of your modules. odoo-ls indexes for some seconds (progress in the status bar).

What is detected for you, unless you set it: the database (the `-d` of the service `command:`),
the container, and the container ↔ local path mappings (from the service `volumes:`).
The odoo-ls config file is generated from these settings.

### Debugging

Publish the debug port in your compose file and have debugpy in the image:

```yaml
services:
  odoo:
    ports: ["8069:8069", "5678:5678"]
```

```dockerfile
RUN pip3 install debugpy   # add --break-system-packages on recent images
```

Then `F9` on a line and `F5`.

## Layout

| Path | What |
|---|---|
| `lua/odoo/local.lua` | **your** settings (`:Odoo config`) |
| `lua/odoo/settings.lua` | every option and its default |
| `lua/odoo/` | Odoo commands, pickers, log panel, odoo-ls config generator |
| `lua/plugins/` | one file per topic: lsp, debug, git, ui, explorer, ai... |
| `lua/config/` | options, keymaps, autocmds |
| `snippets/` | Odoo snippets (VSCode format) |
| `CHEATSHEET.md` | every shortcut (`Space ?`) |

## Notes

- Made for Odoo 18 in Docker. Other versions should work (snippets target 17/18 syntax).
  A non-Docker install gets the editor features, but the `Space o` server commands need Docker.
- Line length is 100 for the ruler and ruff (`lua/config/options.lua`, `lua/plugins/lsp.lua`); black follows your repo's `pyproject.toml`.

## License

[The Unlicense](LICENSE) (public domain)
