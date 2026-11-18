# Instructions for AI agents working on this repository

This is a Neovim configuration for Odoo development with Docker. It is Lua, plus a few shell
and Python helpers. `README.md` describes it for users; this file is for changing it.

## Installing and configuring it for someone

Everything is scripted and prints a final `RESULT: ok` or `RESULT: failed (...)` line:

```bash
scripts/install.sh --yes              # checks programs, links ~/.config/nvim, installs odoo-ls,
                                      # plugins, Mason tools, parsers and the odoo-nvim command
odoo-nvim setup --workspace <addons repo> [--own <dir>]... [--core <dir>] [--python <path>]
odoo-nvim doctor --json               # is everything in place
```

- `install.sh` never runs sudo. When programs are missing it lists them with the install
  command and stops: run that command (or ask the user to), then run the script again.
- `setup` reads the compose file and the mounted `odoo.conf`, and detects the Odoo binary, the
  debug port, the web port and a project `.venv`. It cannot know which addons
  folders are the user's own code or which Python to use: pass `--own` / `--python`, or ask.
  It prints `CHECK:` lines for what it guessed. It does not replace an existing
  `lua/odoo/local.lua` without `--force`.
- `scripts/install.sh --dry-run` reports without changing anything.

## Layout

| Path | What |
|---|---|
| `init.lua`, `lua/config/` | options, keymaps, autocmds, plugin manager, tool lists (`tools.lua`) |
| `lua/plugins/` | one file per topic (lsp, debug, git, ui, ai...), lazy.nvim specs |
| `lua/odoo/settings.lua` | every Odoo setting and its default; reads `local.lua` |
| `lua/odoo/compose.lua` | what to run: compose file facts and command argument lists. No UI, no plugins |
| `lua/odoo/docker.lua`, `log.lua` | run those commands in the editor's log panel |
| `lua/odoo/commands.lua` | every `:Odoo` sub-command with its `<Space>o` key |
| `lua/odoo/paths.lua`, `traceback.lua`, `tests.lua` | path mapping, log parsing, test tags |
| `lua/odoo/detect.lua`, `health.lua`, `agent.lua` | `setup`, `doctor`, the agent brief |
| `lua/odoo/catalog.lua` | the ONE list of `odoo-nvim` commands agents may run: feeds the brief table and `odoo-nvim commands --json` |
| `scripts/cli.lua`, `scripts/odoo-nvim` | the command line tool (runs with `nvim -u NONE -l`) |
| `scripts/bootstrap.lua`, `install*.sh` | unattended install |
| `tests/` | mini.test specs; `tests/fake-docker/docker` stands in for Docker |

## Rules

- `make check` must pass before you call a change done: StyLua, selene, lua-language-server
  and the tests. `make fmt` formats.
- Modules that `scripts/cli.lua` loads (`settings`, `compose`, `paths`, `traceback`, `tests`,
  `last_run`, `health`, `detect`, `agent`, `catalog`, `frontend`) must not use plugins, `Snacks`, windows or
  `vim.notify`: they run without the editor. UI belongs in `docker.lua`, `log.lua`,
  `pickers.lua`, `init.lua`.
- A new Odoo action is an argument list in `compose.lua`, a runner in `docker.lua`, one entry
  in `commands.lua` (name, description, key) and, if useful to agents, a CLI command.
- Public functions carry LuaCATS annotations (`---@param`, `---@return`). Comments say why.
- Keep the style of the file: 2 spaces, 120 columns, simple functions on one line.
- A new CLI command goes into `lua/odoo/catalog.lua` (or into `not_listed` with the reason) and into the
  USAGE text of `scripts/cli.lua`: `tests/test_catalog.lua` fails otherwise. Agents only know the
  commands that are in the brief generated from that list.
- Add a test for behaviour you add or fix. Tests build a throw-away project with
  `H.project()` and never touch the real Docker.
- New keys go in the plugin spec or `commands.lua` with a `desc`, and in `CHEATSHEET.md`.

## Do not touch

- `lua/odoo/local.lua`: the user's own settings (git-ignored). Change it only through
  `odoo-nvim setup` or when the user asks.
- The user's `docker-compose.yml`. Debug mode uses a generated override file instead.
- `lazy-lock.json` by hand: it is written by `:Lazy update`.
