# Neovim for Odoo — cheat sheet

Open this anytime with **`<Space>?`** (`q` closes it). `<Space>` = the space bar.
**Press `<Space>` and wait half a second: a menu shows every shortcut.** Same for `g`, `z`, `[`, `]`.
Forgot a shortcut? `<Space>sk` searches all of them by description ("breakpoint", "rename"...).

```
cd ~/odoo/my-addons && nvim             # open the project (dashboard + folder tree appear)
nvim my_module/models/foo.py
```

---

## 1. Survival kit (read this first)

Neovim has **modes**. The mode is shown bottom-left.

| Mode | What it is | Enter with | Leave with |
|---|---|---|---|
| NORMAL | move around, run commands (default) | `Esc` | — |
| INSERT | type text like any editor | `i` (before cursor) `a` (after) `o` (new line below) `O` (above) | `Esc` |
| VISUAL | select text | `v` (chars) `V` (lines) `Ctrl+v` (block), or drag the mouse | `Esc` |
| COMMAND | `:something` | `:` | `Enter` / `Esc` |

| Do this | Keys |
|---|---|
| Save | `Ctrl+s` (or `:w`) |
| Quit (asks to save) | `Ctrl+q` / `:q` · quit without saving `:q!` |
| Undo / Redo | `u` / `Ctrl+r` |
| Copy / Cut / Paste | select with `v`, then `y` (copy) `d` (cut) · `p` paste. Uses the system clipboard. |
| Copy / delete a line | `yy` / `dd` |
| Go to line 120 | `120G` or `:120` |
| Top / bottom of file | `gg` / `G` |
| Next word / previous word | `w` / `b` |
| Start / end of line | `0` or `^` / `$` |
| Search in file | `/text` then `Enter`, `n` next, `N` previous, `Esc` clears highlight |
| Jump back / forward (after gd...) | `Ctrl+o` / `Ctrl+i` |
| Comment line / selection | `Ctrl+/` or `gcc` / `gc` |
| Indent selection | `>` / `<` (or `Tab` / `Shift+Tab` in visual mode) |
| Move line up / down | `Alt+j` / `Alt+k` (or `Alt+↑/↓`) |
| Repeat last change | `.` |

The mouse works for everything: click, scroll, select, resize splits, click tabs.

**20-minute interactive tutorial:** run `:Tutor`. Do it once, it is worth it.

Vim "grammar" (the superpower): **verb + (count) + object**. `d` delete, `c` change, `y` copy, `v` select.
Objects: `w` word, `"` string, `(` brackets, `f` function, `c` class, `a` argument, `t` XML tag.
`i` = inside, `a` = around. Examples: `ciw` change word · `di"` delete inside quotes ·
`yaf` copy whole function · `vic` select class body · `cit` change XML tag content · `d3j` delete 4 lines.

---

## 2. VSCode → Neovim

| VSCode | Here |
|---|---|
| Ctrl+P quick open | `Ctrl+p` or `<Space><Space>` (smart: recent + git files) |
| Ctrl+Shift+F search in files | `<Space>/` (folder) · `<Space>oa` (ALL addons incl. Odoo core) |
| Search & replace in files | `<Space>sR` (this folder) · `<Space>sM` (this module) |
| Ctrl+B explorer | `Ctrl+b` or `<Space>e` · current file in tree: `<Space>E` |
| Tabs | top bar. `Shift+h` / `Shift+l` previous / next · close `<Space>bd` · pick `<Space>bj` |
| Ctrl+Tab recent files | `<Space>,` (open files) · `<Space>fr` (recent) |
| F12 / Ctrl+click go to definition | `gd` or `F12` |
| Shift+F12 references | `gr` or `Shift+F12` |
| Hover | `K` |
| F2 rename | `F2` / `<Space>cr` (not in Odoo files: odoo_ls has no rename → use `<Space>sM`) |
| Ctrl+. quick fix | `<Space>ca` or `Ctrl+.` |
| Problems panel | `<Space>xx` · next/prev problem `]d` / `[d` |
| Outline | `<Space>cS` (side bar) · `<Space>ss` (fuzzy) |
| Ctrl+D multi-cursor | `Ctrl+n` (repeat to add next match, `q` skip, `Esc` exit) · Ctrl+Alt+↓ cursor below |
| Ctrl+` terminal | `Ctrl+\` (toggle) · `<Space>tf` floating · in terminal `Esc Esc` → normal mode |
| Split editor | `<Space>\|` right · `<Space>-` below · move between `Ctrl+h/j/k/l` |
| Source control | `<Space>gg` (lazygit) · changed lines in the left column |
| Command palette | `<Space>sc` (commands) · `<Space>sk` (shortcuts) · `:Odoo` (Odoo commands) |
| Format | `<Space>cf` (Python of your addons is formatted with black on save) |
| Zen mode | `<Space>z` |

---

## 3. Odoo: everything under `<Space>o`

The module is detected from the file you're in (the folder with `__manifest__.py`).
Commands run against the Odoo service of your `docker-compose.yml` and the database of its
`command:` (`-d mydb`; change with `<Space>oD`). Your paths and names: **`:Odoo setup`** detects them, `:Odoo config` edits them; check with `<Space>o?`
or `:Odoo health`.

### Server / module
| Keys | Action |
|---|---|
| `<Space>ou` | **Update module + restart** (after Python OR XML changes). Saves all files first. |
| `<Space>oU` | Update module without restart (XML/views/data only, faster) |
| `<Space>oi` | Install a module (picker) |
| `<Space>or` | Restart Odoo · `<Space>oS` start (normal mode) · `<Space>oK` stop |
| `<Space>ol` | Follow the Odoo log |
| `<Space>oB` | Open Odoo in the browser with `?debug=1` |
| `<Space>o?` | Status: container / debug mode / DB / module |
| `:Odoo` | Menu with every Odoo command (`:Odoo update my_module` works too, with Tab completion) |

### Tests
| Keys | Action |
|---|---|
| `<Space>ot` | Run all tests of the current module |
| `<Space>oT` | **Run only the test under the cursor** (method, or class if you're on the class line) |

### The output panel (bottom)
Update/test/log output streams there.
- **`Enter` on a traceback line opens that file at that line** (`/mnt/...` container paths are translated to your files). Works for `File "...", line N` and XML `while parsing ...xml:N`.
- When a command fails, all traceback locations go to the quickfix list: **`<Space>xq`**, then `]q` / `[q` to walk them. Your own code comes first.
- `<Space>oq` does the same for whatever is in the log panel (e.g. after `<Space>ol`).
- `q` closes the panel, `Ctrl+c` stops the command.

### Consoles
`<Space>os` Odoo shell (Python with `env`, try `env['res.partner'].search_count([])`) ·
`<Space>op` psql · `<Space>ob` bash in the container.

### Find things in Odoo (core + OCA + yours)
| Keys | Finds |
|---|---|
| `gd` / `K` | **odoo_ls**: definition / docs of fields, models in `env['x']`, `_inherit = 'x'`, `comodel_name`, XML ids in `ref="..."` and `inherit_id`… Hover on a model lists every module that inherits it. |
| `<Space>om` | Every model: where it's defined (●) and every module extending it (○) |
| `<Space>oM` | Same, filtered by the model under the cursor |
| `<Space>ov` | **Views, actions, menus and rules of the model** you are in (or under the cursor) |
| `<Space>ox` / `<Space>oX` | XML ids (records, templates, menus) / XML id under cursor |
| `<Space>oo` | Modules → `Enter` opens the manifest, `Ctrl+e` opens it in the explorer |
| `<Space>o.` | Manifest of the current module |
| `<Space>of` / `<Space>og` | Files / grep **in the current module** |
| `<Space>oc` / `<Space>oC` | Files / grep **in Odoo core** (the local copy, refresh with `:Odoo sync-core`) |
| `<Space>oA` / `<Space>oa` | Files / grep in **ALL addons** (yours + OCA + third party + core) |
| `<Space>ow` | Word under cursor in ALL addons |

Odoo core, OCA and third-party files are marked **read-only** (you'll be warned before saving):
read them, set breakpoints in them, but extend them from your module.

---

## 4. Debugging (debugpy, like VSCode)

1. Put a breakpoint: **`F9`** on a line (red ●). Works in your code AND in Odoo core files.
2. Press **`F5`**. The first time it asks to restart Odoo in *debug mode* (same command as
   `docker-compose.yml` but under debugpy); then it attaches. Odoo stays in debug mode until
   `<Space>oS`, so later `F5` attaches instantly.
3. Use Odoo in the browser. When the code reaches the breakpoint, Neovim jumps there and the panels open:
   variables (left), watches, call stack, breakpoints, and a REPL (bottom) to run Python in that frame
   (`self.env.user.name`, `rec.read(['name'])`...).

| Keys | Action |
|---|---|
| `F5` | Start / continue |
| `F10` / `F11` / `Shift+F11` | Step over / into / out |
| `F9` | Toggle breakpoint |
| `Shift+F5` / `<Space>dt` | Stop debugging (Odoo keeps running) |
| `<Space>dB` | Conditional breakpoint (`rec.id == 42`) |
| `<Space>dl` | Log point (prints a message without stopping: `total={total}`) |
| `<Space>dC` | Run to cursor |
| `<Space>dh` | Value of the thing under cursor · `<Space>de` evaluate expression/selection |
| `<Space>dw` | Add to watches |
| `<Space>dE` | Toggle "stop on every raised exception" |
| `<Space>dL` / `<Space>dX` | List / delete all breakpoints |
| `<Space>dr` | Show/hide the debug panels |

Breakpoints are remembered between sessions. `<Space>ou` (update + restart) re-attaches the debugger by itself.
Tests can be debugged too: be in debug mode, set a breakpoint in the test, `F5`, then `<Space>oT`.

---

## 5. Snippets (type, then `Tab` or `Enter`)

Type the prefix, pick it in the menu, then `Tab` / `Shift+Tab` jump between the fields to fill.
All Odoo snippets start with **`o`**: type `o` + a few letters and look at the menu.

**Python** — `omodel` new model · `oinherit` extend model · `owizard` · `oimports` ·
fields: `ofchar` `oftext` `ofhtml` `ofint` `offloat` `ofmonetary` `ofbool` `ofdate` `ofdatetime` `ofsel`
`ofm2o` `ofo2m` `ofm2m` `ofrelated` `ofbinary` `ofimage` `ofcompany` ·
`ocompute` (field + method) `ocomputeinv` `oonchange` `oconstrains` `osql` ·
overrides: `ocreate` `owrite` `ounlink` `ocopy` `odefault` `odisplayname` `osuper` ·
`obuttonmethod` `ocronmethod` · ORM: `osearch` `ocount` `oreadgroup` `oref` `osudo` `ocontext` `ofiltered` ·
`oerror` `ovalerror` `ologger` `olog` · actions: `oactwindow` `oactform` `oactwizard` `oactnotify` `oactreload` ·
`ocontroller` · tests: `otest` `otestmethod` `otestraises` `otestform` · `omanifest` `ohook` `oimport`

**XML** — `oodoo` · views: `oform` `olist` `olistedit` `osearch` `okanban` `oinheritview` `oxpath` `oxpathany`
`oattr` (change attribute) `ofield` `ofieldif` `ofieldm2o` `obutton` `obuttonaction` `osmartbutton` `ogroup` `opage` `ochatter` ·
`oaction` `omenu` `omenuroot` `oserveraction` `ocron` `osequence` `osecgroup` `orule` `oparam` `osettings`
`oreport` `omailtemplate` · QWeb/OWL: `otforeach` `otif` `oowltemplate` `oowlinherit`

**JS (OWL)** — `oowl` component · `oowlaction` client action · `oowlfield` field widget · `opatch` ·
`oorm` `osearchread` `orpc` `onotify` `odoaction`

**CSV** — `oacl` (ir.model.access.csv header + rows) · `oaclrow`

Snippets live in `nvim/snippets/*.json` (VSCode format) — add your own there.
Plus hundreds of generic ones (friendly-snippets): `def`, `class`, `for`, `try`, `ifmain`...

---

## 6. Files & folders

| Keys | Action |
|---|---|
| `Ctrl+b` / `<Space>e` | Explorer side bar (opens by itself at startup on wide windows). Inside: `a` new file (end with `/` for folder) · `d` delete · `r` rename · `c` copy · `m` move · `Y` copy path · `H` hidden files · `/` filter · `.` make folder root · `Backspace` go up · `?` help |
| `<Space>fe` | Explorer rooted at the current module |
| `-` | **oil**: edit the folder like text (rename = edit the line, delete = `dd`, new = type a name; `:w` applies) |
| `<Space>fp` | Jump to another project folder (your addons folders, each OCA repo...) |
| `<Space>fr` | Recent files · `<Space>fc` this Neovim config |
| `<Space>fy` / `<Space>fY` | Copy full / relative path of the current file |
| `<Space>qs` | Restore the files you had open last time in this folder |

Inside any picker: type to filter · `Ctrl+j/k` or arrows to move · `Enter` open ·
`Ctrl+v` open in vertical split · `Ctrl+s` horizontal split · `Tab` select several · `Ctrl+q` → quickfix · `Esc` close.

## 7. Git

`<Space>gg` **lazygit** (stage with `space`, commit `c`, push `P`, branches `b`; press `?` inside) ·
`]h` / `[h` next/prev change · `<Space>ghp` preview change · `<Space>ghs` stage change · `<Space>ghr` undo change ·
`<Space>gb` blame line · `<Space>ub` inline blame · `<Space>gd` diff of all changes · `<Space>gD` my branch vs `18.0_staging` ·
`<Space>gH` history of this file · `<Space>gs` status · `<Space>gl` log · `<Space>go` open on GitHub.

## 8. Moving fast

`s` + 2 letters + label → jump anywhere on screen (flash) · `]f` `[f` next/prev function · `]c` `[c` class ·
`]]` `[[` next/prev use of the word under cursor · `]t` `[t` TODOs · `<Space>st` list TODOs ·
`%` jump to matching bracket/tag · `za` fold/unfold · `zR` open all folds · `zM` close all.

Surround: `gsa` + motion + char (e.g. `gsaiw"` puts quotes around a word) · `gsd"` delete quotes · `gsr"'` replace `"` by `'`.

## 9. Toggles `<Space>u`

`uf` format on save · `ud` diagnostics · `uh` inlay hints · `un` relative numbers · `uw` wrap · `ub` git blame ·
`uc` sticky class/def header (off by default: it makes fast scrolling laggy; the current class › method
is always in the status bar) · `ug` indent guides · `uC` colorscheme · `uN` dismiss notifications ·
`um` **minimap** on the right of each code window, like VSCode (colours, errors, git changes, search
matches; click it to jump).

---

## 10. Claude Code `<Space>a`

Needs the `claude` CLI. Claude opens in a panel on the right and sees the file / selection you have open.

| Keys | Action |
|---|---|
| `<Space>ac` | Open / close Claude · `Ctrl+,` or `<Space>af` jump to it |
| `<Space>ab` | Give Claude the current file · in the explorer: `<Space>as` on a file |
| `<Space>as` (visual) | Send the selected lines |
| `<Space>al` | Give Claude the output of the last Odoo update / install / test (tracebacks with local paths) |
| `<Space>ax` | Same, and types "find the cause and fix it" in Claude's prompt (you press Enter) |
| `<Space>aa` / `<Space>ad` | Accept / reject the change Claude proposes (shown as a diff) |
| `<Space>ar` / `<Space>aC` | Resume a past conversation / continue the last one |
| `<Space>am` | Choose the model |

In the Claude panel: `Esc Esc` or `Ctrl+\ Ctrl+n` leaves typing mode, then `Ctrl+h` goes back to the code.

Claude also sees your diagnostics (errors and warnings) without you sending them. Files it edits
reload by themselves; review everything it changed with `<Space>gd` (diff of all changes) and
`]h` / `[h` + `<Space>gh…` on single hunks.

**Let Claude update and test by itself.** `:Odoo ai-init` writes a short brief into the `AGENTS.md`
/ `CLAUDE.md` of your addons repo: it tells any AI agent to use the `odoo-nvim` command, which
folders are yours and which are read-only. In a terminal:

```
odoo-nvim update my_module          odoo-nvim test my_module
odoo-nvim test /my_module:TestSale.test_confirm        odoo-nvim logs --tail 100
odoo-nvim last                      odoo-nvim info        odoo-nvim doctor        odoo-nvim help
```

Each ends with `RESULT: ok` / `RESULT: failed ...` and lists the failing file:line of your code.

---

## 11. How it is set up

```
~/.config/nvim/              ← this config
  init.lua                   entry point
  lua/config/                options, general keymaps, autocmds, plugin manager
  lua/plugins/               one file per topic (lsp, debug, git, ui, explorer, ai...)
  lua/odoo/local.lua         ← YOUR paths, docker service, DB, debug port (:Odoo setup / config). Git-ignored
  lua/odoo/settings.lua      the defaults for everything local.lua does not set
  lua/odoo/*.lua             Odoo commands, pickers, output panel
  scripts/odoo-nvim          the Odoo commands from a terminal (for scripts and AI agents)
  scripts/install.sh         unattended install · scripts/install-odoo-ls.sh the language server
  scripts/odoo_ls_proxy.py   filter between nvim and odoo_ls (drops ~20 000 useless messages at startup)
  snippets/*.json            Odoo snippets
~/.local/share/nvim/odoo-core/   default place of the Odoo source copied from the Docker image
                             (go-to-definition, browsing, debugging). Refresh: :Odoo sync-core
~/.local/state/nvim/odoo/    generated files: odools.toml (odoo_ls config), docker-compose.debug.yml,
                             last-run.log (output of the last update / test)
```

Language servers: **odoo_ls** (Odoo-aware Python/XML/JS, by Odoo SA) · ruff (lint: flake8 + bugbear
rules) · lemminx (XML) · basedpyright (Python outside Odoo addons) · lua/json/yaml/css/ts.
Formatting: black on save only for Python files of `own_addons`. Never on OCA/core/XML.

Debug mode writes a compose override to `~/.local/state/nvim/odoo/docker-compose.debug.yml`
(your `docker-compose.yml` is never modified). `<Space>oS` returns to normal mode.

## 12. Troubleshooting

| Problem | Fix |
|---|---|
| `gd` / hover do nothing right after opening | odoo_ls indexes for ~15 s at startup (progress in the status bar) |
| odoo_ls doesn't see a new module / branch switch | it restarts by itself when the git commit changes; else `:OdooLs restart` |
| Odoo commands use the wrong folder / container | `:Odoo config`, then restart nvim; `<Space>o?` shows what is used |
| Is everything installed and configured? | `:Odoo health` (= `:checkhealth odoo`), or `odoo-nvim doctor` in a terminal |
| A warning about `local.lua` at startup | it lists every unknown key, wrong type and missing folder: fix them in `:Odoo config` |
| Anything odoo_ls | `:OdooLs health` · `:OdooLs logs` |
| Which servers are attached? | `<Space>cl` (also shown in the status bar) |
| Install/update servers & tools | `:Mason` |
| Update plugins | `<Space>l` (Lazy) then `U` |
| Something is broken | `:checkhealth` · `:messages` · notifications history `<Space>sn` |
| Update fails "service not running" | start Odoo: `<Space>oS` (or F5 for debug mode) |
| F-keys don't reach nvim | your terminal uses them (e.g. F11 fullscreen): disable that shortcut there, or use `<Space>d…` |
| Icons look like squares | install a Nerd Font (e.g. `JetBrainsMono Nerd Font`) and select it in your terminal |
