## Odoo development commands (odoo-nvim)

This project runs Odoo {{version}} in Docker. Apply and test changes with the `odoo-nvim`
command. Do not call `docker compose` or `odoo-bin` yourself: `odoo-nvim` already knows the
compose folder, the service, the database and the ports that do not collide with the server.

| Task | Command |
|---|---|
| Apply a change to a module (Python, XML, data, fields) | `odoo-nvim update <module>` |
| Install a module | `odoo-nvim install <module>` |
| Run the tests of a module | `odoo-nvim test <module>` |
| Run one test class or method | `odoo-nvim test /<module>:<Class>.<method>` |
| Read the server log | `odoo-nvim logs --tail 200` |
| Output of the last update / install / test again | `odoo-nvim last` |
| Start / stop / restart the server | `odoo-nvim start`, `stop`, `restart` |
| What is configured, is everything in place | `odoo-nvim info`, `odoo-nvim doctor` |

Every command prints the server output with paths of this machine (not of the container),
ends with a `RESULT: ok ...` or `RESULT: failed ...` line and exits with 1 on failure. Add
`--json` to `update`, `install` and `test` for one JSON object instead:
`{ok, summary, log_errors, problems: [{file, line, text}], log}`.

Loop for a change: edit, `odoo-nvim update <module>`, `odoo-nvim test <module>`, and on a
failure open the files under "Problem locations" (your own code is listed first).

### Where the code is

- Write code only here: {{own_addons}}
- Read-only, never edit (OCA, third party, Odoo core; read them to see how something works):
  {{readonly_paths}}
- Odoo {{version}} source: {{core}}
- Database: `{{database}}`. Odoo in the browser: {{web_url}}
