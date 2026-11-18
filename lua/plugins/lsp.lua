-- Language servers (LSP) = go to definition, hover docs, completion, errors, rename...
--
--  odoo_ls      Odoo's official server: knows models, fields, env['x'], _inherit, XML ids,
--               manifests. Its config (odools.toml) is generated from your settings: lua/odoo/odools.lua
--  basedpyright Python outside Odoo addons (odoo_ls covers Odoo code; both at once = duplicates)
--  ruff         fast linter (same rules as the repo's flake8: line 100, bugbear)
--  lemminx      XML (tags, attributes, closing tags)
--  lua_ls       Lua (this config)
--  JSON, YAML, CSS and TypeScript have Treesitter highlighting only, no language server: their
--               servers need Node.js, which this config does not use
--
--  :checkhealth vim.lsp   which servers are attached and why
--  :OdooLs health         odoo_ls status (profile, paths, errors)   :OdooLs restart after git pull
--  :Mason                 install/update servers and tools
return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = { ui = { border = "rounded" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = require("config.tools").mason,
      run_on_start = true,
      debounce_hours = 24, -- look for missing tools once a day, not at every start
    },
  },

  -- Odoo language server client (binary: ~/.local/bin/odoo_ls_server)
  {
    "odoo/odoo-neovim",
    ft = { "python", "xml", "csv", "javascript", "typescript" },
    cmd = "OdooLs",
    opts = {},
    init = function()
      -- Workspace = settings.workspace (your repo), not a parent folder holding Odoo core too:
      -- then the server treats all of core as "your project" and streams ~28 000 diagnostic
      -- messages while indexing, which starves Neovim's screen updates for ~30 s.
      -- Core / OCA files you open still use the same server (one client for every buffer).
      vim.lsp.config("odoo_ls", {
        -- through a small proxy that drops the flood of empty diagnostics (see scripts/odoo_ls_proxy.py)
        cmd = function(dispatchers, config)
          local settings = require("odoo.settings")
          local cmd = {
            "python3",
            vim.fn.stdpath("config") .. "/scripts/odoo_ls_proxy.py",
            settings.odoo_ls_cmd,
            "--log-level",
            "info",
            "--config-path",
            require("odoo.odools").path(),
          }
          return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
        end,
        root_markers = false,
        root_dir = function(bufnr, on_dir)
          local odoo = require("odoo")
          local fname = vim.api.nvim_buf_get_name(bufnr)
          if odoo.is_odoo_file(fname) or fname:find(odoo.settings.workspace, 1, true) == 1 then
            on_dir(odoo.settings.workspace)
          end
        end,
      })
    end,
  },

  -- Better Lua completion when editing this config
  { "folke/lazydev.nvim", ft = "lua", opts = { library = { { path = "snacks.nvim", words = { "Snacks" } } } } },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
    config = function()
      require("mason") -- puts Mason's bin folder on PATH
      local odoo = require("odoo")

      -- Diagnostics (errors / warnings) look
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = { spacing = 2, prefix = "●", source = "if_many" },
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = "󰌵 ",
          },
        },
      })

      -- Server progress ("odoo_ls: Indexing… 45%") is shown in the statusline: lua/config/status.lua

      -- completion capabilities for every server
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities({}, false) })

      -- ---------------------------------------------------------- Python
      local function not_odoo_root(markers)
        return function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          if odoo.is_odoo_file(fname) and not vim.g.odoo_also_pyright then return end
          on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(fname))
        end
      end

      vim.lsp.config("basedpyright", {
        root_dir = not_odoo_root({ "pyproject.toml", "setup.py", "requirements.txt", "pyrightconfig.json", ".git" }),
        settings = {
          python = { pythonPath = odoo.settings.python },
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoImportCompletions = true,
              extraPaths = { odoo.settings.core },
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        -- same position encoding as odoo_ls (both attach to Odoo Python files)
        capabilities = { general = { positionEncodings = { "utf-16" } } },
        init_options = {
          settings = {
            configurationPreference = "filesystemFirst", -- a [tool.ruff] in pyproject wins
            configuration = {
              ["line-length"] = 100,
              lint = {
                select = { "E", "F", "W", "B" }, -- ≈ flake8 + flake8-bugbear like pre-commit
                ignore = { "E203", "E501" }, -- black handles line length
                ["per-file-ignores"] = { ["__init__.py"] = { "F401" }, ["__manifest__.py"] = { "B018" } },
              },
            },
          },
        },
      })

      -- ---------------------------------------------------------- XML
      vim.lsp.config("lemminx", {
        settings = {
          xml = {
            format = {
              enabled = true,
              splitAttributes = "preserve",
              maxLineWidth = 0,
              preserveEmptyContent = true,
              insertSpaces = true,
              tabSize = 4,
              preservedNewlines = 2,
            },
            completion = { autoCloseTags = true },
            validation = { noGrammar = "ignore" }, -- Odoo XML has no DTD/XSD
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = { Lua = { workspace = { checkThirdParty = false }, completion = { callSnippet = "Replace" } } },
      })

      vim.lsp.enable({ "basedpyright", "ruff", "lemminx", "lua_ls" })

      -- ---------------------------------------------------------- keys when a server is attached
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_lsp", { clear = true }),
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false -- leave hover to odoo_ls / pyright
          end
          local map = function(lhs, rhs, desc, mode)
            vim.keymap.set(mode or "n", lhs, rhs, { buffer = ev.buf, desc = desc, silent = true })
          end
          map("gd", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("<F12>", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("gr", function() Snacks.picker.lsp_references() end, "References (who uses this)")
          map("<S-F12>", function() Snacks.picker.lsp_references() end, "References")
          map("gI", function() Snacks.picker.lsp_implementations() end, "Go to implementation")
          map("gy", function() Snacks.picker.lsp_type_definitions() end, "Go to type definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover documentation")
          map("gK", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action / quick fix", { "n", "x" })
          map("<C-.>", vim.lsp.buf.code_action, "Code action / quick fix", { "n", "x" })
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<F2>", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>cs", function() Snacks.picker.lsp_symbols() end, "Symbols in file")
          map("<leader>cl", "<Cmd>checkhealth vim.lsp<CR>", "LSP info")
          map("<leader>cR", "<Cmd>lsp restart<CR>", "Restart language servers")
          map(
            "<leader>co",
            function()
              vim.lsp.buf.code_action({
                apply = true,
                context = { only = { "source.organizeImports" }, diagnostics = {} },
              })
            end,
            "Organize imports"
          )
        end,
      })
    end,
  },
}
