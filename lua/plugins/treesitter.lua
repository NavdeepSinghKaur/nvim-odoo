-- Treesitter: real syntax trees -> accurate colours, indentation, folding, and "text objects"
--   vif / vaf   select inside / around a function (def)      vic / vac  a class
--   via / vaa   an argument   vit / vat  an XML tag   vi" / va"  a string   vib  brackets
--   (any operator works: dif = delete function body, yac = copy class, cia = change argument)
--   ]f [f next/prev function    ]c [c next/prev class
--   The statusline shows which class/method you are in (<Space>uc: sticky header at the top).
local parsers = require("config.tools").parsers

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})

      -- install the missing parsers in the background (needs the tree-sitter CLI + a C compiler)
      local function install_missing()
        local treesitter = require("nvim-treesitter")
        local installed = treesitter.get_installed()
        local missing = vim.tbl_filter(function(p) return not vim.tbl_contains(installed, p) end, parsers)
        if #missing > 0 then treesitter.install(missing) end
      end

      -- The CLI comes from Mason. Loading Mason puts its bin folder first on PATH.
      require("lazy").load({ plugins = { "mason.nvim" } })
      if vim.fn.executable("tree-sitter") == 1 then
        install_missing()
      else
        -- First start: install the CLI, then the parsers. Checked again on every start (no debounce),
        -- and a Mason problem must not break startup.
        pcall(function()
          local registry = require("mason-registry")
          registry.refresh(function() -- asynchronous: its errors would not reach the pcall above
            pcall(function()
              local package = registry.get_package("tree-sitter-cli")
              if package:is_installed() then return vim.schedule(install_missing) end
              package:install():once(
                "closed",
                vim.schedule_wrap(function()
                  if package:is_installed() then install_missing() end
                end)
              )
            end)
          end)
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(ev)
          if not pcall(vim.treesitter.start, ev.buf) then return end
          local ft = vim.bo[ev.buf].filetype
          if ft ~= "python" and ft ~= "yaml" then -- python's own indent is better than ts indent
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    opts = function()
      local ts = require("mini.ai").gen_spec.treesitter
      return {
        n_lines = 500,
        custom_textobjects = {
          f = ts({ a = "@function.outer", i = "@function.inner" }),
          c = ts({ a = "@class.outer", i = "@class.inner" }),
          o = ts({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
        },
      }
    end,
  },

  -- queries for function/class/argument text objects (used by mini.ai below) and the
  -- jumps between functions / classes
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    lazy = true,
    keys = (function()
      local function mv(dir, q)
        return function() require("nvim-treesitter-textobjects.move")[dir](q, "textobjects") end
      end
      return {
        { "]f", mv("goto_next_start", "@function.outer"), desc = "Next function", mode = { "n", "x", "o" } },
        { "[f", mv("goto_previous_start", "@function.outer"), desc = "Previous function", mode = { "n", "x", "o" } },
        { "]c", mv("goto_next_start", "@class.outer"), desc = "Next class", mode = { "n", "x", "o" } },
        { "[c", mv("goto_previous_start", "@class.outer"), desc = "Previous class", mode = { "n", "x", "o" } },
      }
    end)(),
    opts = { move = { set_jumps = true } },
  },

  -- sticky header: current class / def / XML <record> stays visible at the top.
  -- OFF by default: it is a floating window, and any float on screen makes the terminal repaint
  -- everything on each scroll step (laggy fast scrolling). The statusline shows "Class › method"
  -- instead. Turn it on when you want it with <Space>uc.
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = { enable = false, max_lines = 4, multiline_threshold = 1, trim_scope = "inner" },
    keys = { { "<leader>uc", "<Cmd>TSContext toggle<CR>", desc = "Toggle sticky context" } },
  },

  -- auto close and auto rename XML/HTML tags
  { "windwp/nvim-ts-autotag", ft = { "xml", "html", "javascript", "typescript" }, opts = {} },
}
