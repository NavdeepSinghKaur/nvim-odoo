-- Treesitter: real syntax trees -> accurate colours, indentation, folding, and "text objects"
--   vif / vaf   select inside / around a function (def)      vic / vac  a class
--   via / vaa   an argument   vit / vat  an XML tag   vi" / va"  a string   vib  brackets
--   (any operator works: dif = delete function body, yac = copy class, cia = change argument)
--   ]f [f next/prev function    ]c [c next/prev class
--   The statusline shows which class/method you are in (<Space>uc: sticky header at the top).
local parsers = {
  "python", "xml", "html", "javascript", "typescript", "css", "scss", "json", "yaml", "toml",
  "lua", "luadoc", "vim", "vimdoc", "query", "markdown", "markdown_inline", "bash", "sql", "csv",
  "po", "rst", "regex", "diff", "gitcommit", "git_rebase", "gitignore", "dockerfile", "ini",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})
      -- install missing parsers in the background (needs the tree-sitter CLI + a C compiler)
      local installed = require("nvim-treesitter").get_installed()
      local missing = vim.tbl_filter(function(p) return not vim.tbl_contains(installed, p) end, parsers)
      if #missing > 0 then require("nvim-treesitter").install(missing) end

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

  -- queries for function/class/argument text objects (used by mini.ai below)
  { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main", lazy = true },

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
          o = ts({ a = { "@block.outer", "@conditional.outer", "@loop.outer" }, i = { "@block.inner", "@conditional.inner", "@loop.inner" } }),
        },
      }
    end,
  },

  -- jump between functions / classes
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
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
