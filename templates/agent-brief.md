## Odoo development commands (odoo-nvim)

This project runs Odoo {{version}} in Docker. Apply and test changes with the `odoo-nvim`
command. Do not call `docker compose` or `odoo-bin` yourself: `odoo-nvim` already knows the
compose folder, the service, the database and the ports that do not collide with the server.

{{commands}}

Every command prints the server output with paths of this machine (not of the container),
ends with a `RESULT: ok ...` or `RESULT: failed ...` line and exits with 1 on failure. Add
`--json` to `update`, `install` and `test` for one JSON object instead:
`{ok, summary, log_errors, problems: [{file, line, text}], log}`.
`odoo-nvim commands --json` lists these commands for a program; `odoo-nvim help` has every option.

Loop for a change: edit, `odoo-nvim update <module>`, `odoo-nvim test <module>`, and on a
failure open the files under "Problem locations" (your own code is listed first).

### Where the code is

- Write code only here: {{own_addons}}
- Read-only, never edit (OCA, third party, Odoo core; read them to see how something works):
  {{readonly_paths}}
- Odoo {{version}} source: {{core}}
- Database: `{{database}}`. Odoo in the browser: {{web_url}}

### Front-end (Odoo {{version}}: OWL, assets, Bootstrap)

After you write or change JS, XML templates or SCSS, run `odoo-nvim frontend <module>` (no
Docker needed, takes a second): it fails when a file under `static/src` is not loaded by a
bundle of `__manifest__.py`, when a bundle entry does not exist, or when a component's
`static template` has no `t-name`. Then `odoo-nvim update <module>` and reload the browser.

Rules (copy the patterns of the modules in the read-only folders above; OCA `web_*` modules are good examples):

- JS: ES modules, `import { ... } from "@web/..."` / `"@odoo/owl"`. No `odoo.define`, no
  `require("web.…")`, no jQuery, no legacy widgets. File names end in `.esm.js` or `.js`; keep
  one component per file.
- Components: `class X extends Component { static template = "<module>.X"; static props = {...}; setup() {...} }`,
  state with `useState`, services with `useService`. Register with `registry.category("fields" | "actions" | "systray" ...).add(...)`.
  Change existing behaviour with `patch(...)` from `@web/core/utils/patch`, not by copying core code.
- Templates: `static/src/**/*.xml` with `<t t-name="<module>.X">` (prefix = the module name).
  Extend a core template with `t-inherit` + `t-inherit-mode="extension"` and xpath.
- Bundles: list every JS / XML / SCSS file under `assets` in `__manifest__.py`
  (`web.assets_backend` for the backend, `web.assets_frontend` for the website/portal).
- Styling: Bootstrap 5 utility classes in the template first (`d-flex`, `gap-2`, `text-muted`,
  `mb-3`...). Custom SCSS only when no utility does it, using Odoo's variables
  (`$o-brand-primary`, `$border-radius`) and a selector under your component's own class.
  No inline `style=`, no `!important`.
- Translations: `_t("text")` from `@web/core/l10n/translation` in JS, plain text in templates.
