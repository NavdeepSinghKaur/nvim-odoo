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
- **Claude Code** in a side panel (`Space a`) through [claudecode.nvim](https://github.com/coder/claudecode.nvim),
  and an **`odoo-nvim` command** so an AI agent can update a module, run its tests and read the
  traceback by itself ([docs/AI.md](docs/AI.md)).
- **Minimap** on the right of each code window, like VSCode (`Space um`).
- VSCode-like keys (`Ctrl+s`, `Ctrl+p`, `Ctrl+b`, `Ctrl+/`, `F2`, `F12`), file tree, tabs, git
  (lazygit, gitsigns, diffview), format on save with black for your own code only.

## Requirements

- Neovim **0.12+**, git, a C compiler, `curl`, `unzip`, `make` (only for `make check`)
- [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd)
- `tar` and `gzip`. The tree-sitter CLI is installed by Mason on first start (no Node.js or npm needed)
- Python 3 with `python3 -m venv` (package `python3-venv` on Debian/Ubuntu; runs the odoo-ls proxy, Mason needs it)
- A clipboard tool (`xclip` or `wl-clipboard`; WSL uses `clip.exe` / `win32yank.exe`)
- A [Nerd Font](https://www.nerdfonts.com) selected in your terminal (for the icons).
  `scripts/install.sh` runs `scripts/install-font.sh`, which installs JetBrainsMono Nerd Font:
  into `~/.local/share/fonts` on Linux, and for your Windows user (no admin) on WSL, because
  the terminal only sees Windows fonts. Then select `JetBrainsMono Nerd Font Mono` in the
  terminal profile. `--skip-font` skips it
- Docker with the compose plugin, and `debugpy` installed in your Odoo image for debugging
- Optional: [lazygit](https://github.com/jesseduffield/lazygit), the
  [`claude` CLI](https://docs.anthropic.com/en/docs/claude-code)

## Install

```bash
git clone https://github.com/NavdeepSinghKaur/nvim-odoo ~/src/nvim-odoo
~/src/nvim-odoo/scripts/install.sh
```

The script checks the required programs (and tells you how to install the missing ones: it
never runs `sudo`), links the folder as `~/.config/nvim` (an existing config is moved to
`nvim.bak.<date>` after asking), installs odoo-ls into `~/.local`, pre-installs every plugin,
language server and parser, and links the `odoo-nvim` command into `~/.local/bin`. It ends
with `RESULT: ok`. Options: `--yes` (no questions), `--dry-run` (only report).

Prefer to do it by hand? Clone to `~/.config/nvim`, run `scripts/install-odoo-ls.sh`, start
`nvim`: plugins and tools install themselves on first start.

### Let an AI do it

The install and the configuration are scripted end to end, so you can hand both to an agent
(Claude Code, Codex, Cursor...). Tell it where your project is:

> Clone https://github.com/NavdeepSinghKaur/nvim-odoo and set it up as my Neovim config.
> My Odoo addons repo is ~/work/my-addons and my own modules are in its `custom` folder.

It will find [`AGENTS.md`](AGENTS.md), run `scripts/install.sh --yes`, then
`odoo-nvim setup --workspace ... --own ...` and `odoo-nvim doctor`. Details: [docs/AI.md](docs/AI.md).

## Configure (2 minutes)

In Neovim run **`:Odoo setup`** in your addons repo (or `odoo-nvim setup --workspace DIR` in a
terminal). It reads your compose file and the mounted `odoo.conf` and writes
`lua/odoo/local.lua` (git-ignored): compose folder, service names, container, addons folders,
the Odoo executable, the debug port, the web port and a project `.venv`.
What it cannot know is marked `CHECK:` in the file, mainly **which addons are your own code**
(`own_addons`: formatted on save, diagnostics shown) and which Python to use.

```lua
return {
  workspace = "~/odoo/my-addons",                    -- the repo you work in
  own_addons = { "~/odoo/my-addons/custom" },        -- code you write
  addons_paths = { "~/odoo/my-addons/custom", "~/odoo/my-addons/oca" },
  readonly_paths = { "~/.local/share/nvim/odoo-core", "~/odoo/my-addons/oca" },  -- code you only read
  compose_dir = "~/odoo/docker",                     -- folder with docker-compose.yml
  service = "odoo",                                  -- odoo service name in it
  db_service = "db",
}
```

`:Odoo config` opens the file to edit it by hand; every option is in
[`local.example.lua`](lua/odoo/local.example.lua). Restart Neovim, then:

1. `:Odoo health` (`:checkhealth odoo`) checks programs, settings, compose file and container.
   A typo in `local.lua` (unknown key, wrong type, missing folder) is reported at startup.
2. `:Odoo sync-core` copies the Odoo source out of your container/image, so go-to-definition and
   the debugger can open core files. Not needed if you set `core` to an Odoo source checkout.
3. Open a Python file of one of your modules. odoo-ls indexes for some seconds (progress in the status bar).

What is read from the compose file at run time, unless you set it: the database (the `-d` of
the service `command:`), the container, and the container ↔ local path mappings (the service
`volumes:`). The odoo-ls config file is generated from these settings.

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

## From a terminal: `odoo-nvim`

The same Odoo actions without the editor, for scripts and AI agents:

```bash
odoo-nvim update my_module            # -u, then restart the server
odoo-nvim test my_module              # or: odoo-nvim test /my_module:TestSale.test_confirm
odoo-nvim logs --tail 100
odoo-nvim info                        # what is configured        odoo-nvim doctor   # is it healthy
odoo-nvim help
```

Output uses the paths of your machine instead of the container's, ends with `RESULT: ok` or
`RESULT: failed ...` and a list of the failing `file:line`, and the exit code says the same.
`--json` gives one JSON object. `:Odoo ai-init` writes a short brief about these commands into
your addons repo's `AGENTS.md` / `CLAUDE.md`, so an agent uses them unprompted.

## Minimap

`Space um` shows a minimap on the right edge of every code window: the shape of the file in
syntax colours, with errors, git changes and search matches, and a click jumps there. It is
off at start; set `auto_enable = true` in `lua/plugins/ui.lua` to keep it on.
[docs/PLUGINS.md](docs/PLUGINS.md) compares it with the alternatives.

## Plugins

About 45, all pinned in `lazy-lock.json`. The ones doing the heavy lifting:
[lazy.nvim](https://github.com/folke/lazy.nvim) (plugin manager),
[snacks.nvim](https://github.com/folke/snacks.nvim) (pickers, terminal, notifications),
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) +
[mason.nvim](https://github.com/mason-org/mason.nvim) (language servers),
[odoo-ls](https://github.com/odoo/odoo-ls) (Odoo's own language server),
[blink.cmp](https://github.com/saghen/blink.cmp) (completion),
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (syntax),
[nvim-dap](https://github.com/mfussenegger/nvim-dap) (debugger),
[conform.nvim](https://github.com/stevearc/conform.nvim) (formatting),
[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) and
[diffview.nvim](https://github.com/sindrets/diffview.nvim) (git),
[neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) (file tree),
[claudecode.nvim](https://github.com/coder/claudecode.nvim) (Claude Code) and
[neominimap.nvim](https://github.com/Isrothy/neominimap.nvim) (minimap).

**[docs/PLUGINS.md](docs/PLUGINS.md)** lists every plugin with what it does here, how widely
used and how recently maintained it is, the usual alternative, and the AI / MCP / minimap
options that were considered and left out.

## Layout

| Path | What |
|---|---|
| `lua/odoo/local.lua` | **your** settings (`:Odoo setup`, `:Odoo config`) |
| `lua/odoo/settings.lua` | every option and its default |
| `lua/odoo/` | Odoo commands, pickers, log panel, odoo-ls config generator |
| `lua/plugins/` | one file per topic: lsp, debug, git, ui, explorer, ai... |
| `lua/config/` | options, keymaps, autocmds, tool lists |
| `scripts/` | `install.sh`, `odoo-nvim`, odoo-ls installer and proxy |
| `snippets/` | Odoo snippets (VSCode format) |
| `tests/` | tests of the Odoo modules (`make test`) |
| `docs/` | [AI.md](docs/AI.md), [PLUGINS.md](docs/PLUGINS.md) |
| `CHEATSHEET.md` | every shortcut (`Space ?`) |

## Contributing

```bash
make check     # format check (StyLua), lint (selene), types (lua-language-server), tests (mini.test)
make fmt       # format
```

The tools come from Mason, which the config installs itself. The same checks run in CI on every
push. The Lua follows the usual Neovim conventions: StyLua formatting (`stylua.toml`), LuaCATS
annotations on public functions, one topic per file. The Odoo code is split so each module
has one job and the parts without UI (`compose`, `paths`, `traceback`, `tests`, `detect`,
`health`) can be tested and used from the command line; [`AGENTS.md`](AGENTS.md) has the rules
in short form, for people as much as for agents.

## Notes

- Made for Odoo 18 in Docker. Other versions should work (snippets target 17/18 syntax).
  A non-Docker install gets the editor features, but the `Space o` server commands need Docker.
- Line length is 100 for the ruler and ruff (`lua/config/options.lua`, `lua/plugins/lsp.lua`); black follows your repo's `pyproject.toml`.

## License

[The Unlicense](LICENSE) (public domain)
