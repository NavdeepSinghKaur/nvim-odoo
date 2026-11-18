# Working with AI agents

This config is built so that an AI coding agent can do the whole loop by itself: install the
editor, configure it for a project, change code, update the module, run the tests and read
what failed. Nothing here needs a special server: the agent uses ordinary commands.

## 1. Let an agent install and configure it

Give the agent the repository and say what your project is. For example:

> Clone https://github.com/NavdeepSinghKaur/nvim-odoo and set it up as my Neovim config.
> My Odoo addons repo is ~/work/my-addons, my own modules are in ~/work/my-addons/custom.

The agent reads [`AGENTS.md`](../AGENTS.md) and runs:

```bash
scripts/install.sh --yes
odoo-nvim setup --workspace ~/work/my-addons --own ~/work/my-addons/custom
odoo-nvim doctor
```

- `install.sh` checks the required programs, links the config, installs the Odoo language
  server (checksum verified), all plugins at the versions of `lazy-lock.json`, the language
  servers and formatters, and the Treesitter parsers. It never runs `sudo`: when a program is
  missing it prints the command to install it and stops. The last line is `RESULT: ok` or
  `RESULT: failed (...)`.
- `setup` writes `lua/odoo/local.lua`. It reads the compose file (service names, container,
  mounted folders) and the mounted `odoo.conf` (addons path). It cannot know which folders
  hold *your* code or which Python to use, so pass `--own` and `--python`, or check the lines
  it marks `CHECK:`.
- `doctor` verifies programs, settings, compose file, container, debug port and debugpy.
  `--json` gives the same as data.

By hand it is the same three commands, or `:Odoo setup` and `:Odoo health` inside Neovim.

## 2. Let an agent update and test (the `odoo-nvim` command)

`odoo-nvim` runs the same actions as `<Space>o` in the editor, from any terminal:

| Command | What |
|---|---|
| `odoo-nvim update <module> [--no-restart]` | `-u` the module, then restart the server |
| `odoo-nvim install <module>` | `-i` the module, then restart |
| `odoo-nvim test <module>` | run the module's tests |
| `odoo-nvim test /<module>:<Class>.<method>` | one test class or method |
| `odoo-nvim logs [--tail N] [--follow]` | server log |
| `odoo-nvim last` | output of the last update / install / test |
| `odoo-nvim start` / `stop` / `restart` | the Odoo container |
| `odoo-nvim dbs` | databases; `--db NAME` on any command uses another one |
| `odoo-nvim info` / `doctor` | what is configured / is it healthy (`--json`) |
| `odoo-nvim frontend [module]` | JS / XML templates / SCSS loaded by a bundle? (no Docker) |
| `odoo-nvim commands [--json]` | this list, for a program (generated from `lua/odoo/catalog.lua`) |
| `odoo-nvim brief [--write]` | the instructions for agents (below) |

What makes it usable by an agent:

- Paths in the output are **local paths**. Odoo prints `/mnt/extra-addons/...`; the agent
  gets `~/work/my-addons/...` and can open the file.
- After the output comes a list of **problem locations**, your own code first, and one line
  `RESULT: ok ...` or `RESULT: failed ...`. The exit code is 0 or 1 (2 for wrong usage).
- `--json` prints a single object: `{ok, summary, log_errors, problems: [{file, line, text}], log}`.
- It starts in a few milliseconds: Neovim runs it as a plain Lua interpreter without plugins.

Run **`:Odoo ai-init`** (or `odoo-nvim brief --write`) once per addons repo. It writes a short
brief into that repo's `AGENTS.md` (or `CLAUDE.md` if that is what the repo has): the table
above, the loop to follow, which folders are yours and which are read-only. It only owns the
block between its two marker comments, so running it again updates the block and leaves the
rest of the file alone.

**Why this way.** An agent can only use a command it knows about, and it knows what is in its
context: the project's `AGENTS.md` / `CLAUDE.md`, loaded at every session start, in every tool
(Claude Code, Codex, Cursor...). So the commands live there, in a block this config writes and
keeps current. The list is generated from one file (`lua/odoo/catalog.lua`), so the brief, the
`commands --json` output and the tests cannot drift apart, and `:checkhealth odoo` / `odoo-nvim
doctor` warn when the block is missing or old. Claude Code reads `CLAUDE.md` and not `AGENTS.md`,
so `ai-init` also creates a `CLAUDE.md` with the line `@AGENTS.md`. A plain command line tool
needs no server or per-tool setup, which an MCP server would. A Claude Code skill (loaded only
when needed) is a possible next step if the brief grows.

For Claude Code, allow the command once so it does not ask every time. In the addons repo's
`.claude/settings.json`:

```json
{ "permissions": { "allow": ["Bash(odoo-nvim:*)"] } }
```

## 3. Inside the editor

[claudecode.nvim](https://github.com/coder/claudecode.nvim) runs the `claude` CLI in a panel
(`<Space>ac`) and connects it to Neovim the way the VSCode extension does: Claude sees the
open file, your selection and the diagnostics, and proposes edits as diffs you accept
(`<Space>aa`) or reject (`<Space>ad`).

| Keys | What |
|---|---|
| `<Space>al` | add the output of the last Odoo run to the conversation |
| `<Space>ax` | the same, plus "find the cause and fix it" typed in the prompt |
| `<Space>gd` | review every change in the working tree (Diffview) |
| `]h` `[h`, `<Space>gh…` | walk and stage / reset single hunks |

Files changed by the agent reload by themselves when Neovim gets focus. Saving a file in a
read-only folder (Odoo core, OCA) still asks first, whoever edits it.

## 4. Why there is no MCP server here

MCP is how an assistant gets tools. Two kinds were considered:

- **A server that controls Neovim** ([mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server),
  [nvim-mcp](https://pypi.org/project/nvim-mcp/)). claudecode.nvim already gives Claude the
  useful part (files, selection, diagnostics, diffs) over its own connection. A second server
  that can run any editor command adds risk and nothing the workflow needs.
- **A server that talks to the Odoo database** over XML-RPC (several projects are called
  `mcp-server-odoo`). Useful for questions like "which views does this record use", but it
  needs database credentials, and XML-RPC is deprecated from Odoo 19. It is your choice per
  project, so it is not installed. If you want one, add it to the addons repo and point it
  at the **development** database only:

  `.mcp.json` in your addons repo (an example: check the README of the server you choose
  for its real options):

  ```json
  {
    "mcpServers": {
      "odoo-dev": {
        "command": "uvx",
        "args": ["mcp-server-odoo"],
        "env": { "ODOO_URL": "http://localhost:8069", "ODOO_DB": "my_dev_db", "ODOO_USER": "admin", "ODOO_PASSWORD": "admin" }
      }
    }
  }
  ```

A command line tool was chosen instead because every agent can run a command, nothing has to
keep running, and it is the same code the editor uses.

## 5. Safety notes

- `odoo-nvim` only ever talks to the compose service of `lua/odoo/local.lua`, on your machine.
- An agent that can run `odoo-nvim update` can change your development database. Keep
  production credentials out of the project the agent works in.
- `scripts/install.sh` moves an existing `~/.config/nvim` to `nvim.bak.<date>` (it asks,
  unless `--yes`) and never deletes it.
- Other tools: [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) and
  [avante.nvim](https://github.com/avante-corp/avante.nvim) put a chat inside Neovim buffers,
  [sidekick.nvim](https://github.com/folke/sidekick.nvim) adds Copilot's next-edit
  suggestions, [copilot.lua](https://github.com/zbirenbaum/copilot.lua) gives inline
  completion (it can be a blink.cmp source). None is installed: one assistant with the whole
  project in view fits this workflow, and `odoo-nvim` works with any of them.
