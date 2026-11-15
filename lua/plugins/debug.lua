-- Debugger (nvim-dap + debugpy), VSCode keys:
--   F5  start / continue      (first time: restarts Odoo under debugpy and attaches)
--   F9  toggle breakpoint     F10 step over     F11 step into     Shift+F11 step out
--   Shift+F5 stop             <Space>d… everything else (conditional breakpoint, log point,
--   run to cursor, evaluate, REPL, break on exceptions...)
--
-- Breakpoints are saved per file and come back when you reopen nvim.
-- While stopped: hover a variable with <Space>dh, or type expressions in the REPL panel
-- (e.g.  self.env.user.name   or   rec.read(['name', 'state'])  ).
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "mfussenegger/nvim-dap-python",
      "Weissle/persistent-breakpoints.nvim",
    },
    keys = function()
      local dap = function() return require("dap") end
      local pb = function() return require("persistent-breakpoints.api") end
      local function start_or_continue()
        if dap().session() then return dap().continue() end
        if
          require("odoo").is_odoo_file(vim.api.nvim_buf_get_name(0))
          or vim.fn.getcwd():find(require("odoo").settings.root, 1, true)
        then
          return require("odoo").debug()
        end
        dap().continue() -- pick a configuration (e.g. "file" for a plain Python script)
      end
      local stop = function() dap().disconnect({ terminateDebuggee = false }) end -- leaves Odoo running
      return {
        { "<F5>", start_or_continue, desc = "Debug: start / continue" },
        { "<S-F5>", stop, desc = "Debug: stop" },
        { "<F17>", stop, desc = "which_key_ignore" }, -- Shift+F5 in many terminals
        { "<F9>", function() pb().toggle_breakpoint() end, desc = "Toggle breakpoint" },
        { "<F10>", function() dap().step_over() end, desc = "Step over" },
        { "<F11>", function() dap().step_into() end, desc = "Step into" },
        { "<S-F11>", function() dap().step_out() end, desc = "Step out" },
        { "<F23>", function() dap().step_out() end, desc = "which_key_ignore" }, -- Shift+F11
        { "<leader>dc", start_or_continue, desc = "Start / continue (F5)" },
        { "<leader>db", function() pb().toggle_breakpoint() end, desc = "Toggle breakpoint (F9)" },
        { "<leader>dB", function() pb().set_conditional_breakpoint() end, desc = "Conditional breakpoint" },
        { "<leader>dl", function() pb().set_log_point() end, desc = "Log point (print without stopping)" },
        { "<leader>dX", function() pb().clear_all_breakpoints() end, desc = "Delete ALL breakpoints" },
        { "<leader>dL", function() dap().list_breakpoints(true) end, desc = "List breakpoints" },
        { "<leader>dC", function() dap().run_to_cursor() end, desc = "Run to cursor" },
        { "<leader>di", function() dap().step_into() end, desc = "Step into (F11)" },
        { "<leader>do", function() dap().step_over() end, desc = "Step over (F10)" },
        { "<leader>dO", function() dap().step_out() end, desc = "Step out (S-F11)" },
        { "<leader>dj", function() dap().down() end, desc = "Frame down" },
        { "<leader>dk", function() dap().up() end, desc = "Frame up" },
        { "<leader>dt", stop, desc = "Stop debugging (Odoo keeps running)" },
        { "<leader>da", function() require("odoo").attach() end, desc = "Attach to Odoo (already in debug mode)" },
        { "<leader>dr", function() require("dapui").toggle({ reset = true }) end, desc = "Toggle debug panels" },
        { "<leader>dR", function() dap().repl.toggle() end, desc = "REPL (evaluate code)" },
        {
          "<leader>de",
          function() require("dapui").eval(nil, { enter = true }) end,
          desc = "Evaluate expression",
          mode = { "n", "x" },
        },
        { "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "Value under cursor" },
        {
          "<leader>dw",
          function() require("dapui").elements.watches.add(vim.fn.expand("<cexpr>")) end,
          desc = "Watch expression",
        },
        {
          "<leader>dE",
          function()
            vim.g.dap_break_raised = not vim.g.dap_break_raised
            dap().set_exception_breakpoints(vim.g.dap_break_raised and { "raised", "uncaught" } or {})
            vim.notify("Break on raised exceptions: " .. (vim.g.dap_break_raised and "ON" or "OFF"))
          end,
          desc = "Toggle break on exceptions",
        },
      }
    end,
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      -- debugpy installed by Mason (for "Launch file" configs); Odoo uses the container's debugpy
      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      require("dap-python").setup(vim.fn.executable(debugpy) == 1 and debugpy or "python3")
      table.insert(dap.configurations.python, 1, require("odoo").dap_config())
      dap.defaults.python.exception_breakpoints = {} -- Odoo raises a lot internally; toggle with <Space>dE

      require("persistent-breakpoints").setup({ load_breakpoints_event = { "BufReadPost" } })
      require("nvim-dap-virtual-text").setup({ virt_text_pos = "eol" }) -- values next to the code

      dapui.setup({
        layouts = {
          {
            position = "left",
            size = 50,
            elements = {
              { id = "scopes", size = 0.5 },
              { id = "watches", size = 0.15 },
              { id = "stacks", size = 0.25 },
              { id = "breakpoints", size = 0.1 },
            },
          },
          { position = "bottom", size = 12, elements = { { id = "repl", size = 1 } } },
        },
        floating = { border = "rounded" },
      })
      dap.listeners.after.event_initialized["dapui"] = function()
        pcall(vim.cmd, "Neotree close")
        dapui.open()
        vim.notify("Debugger attached. Set breakpoints with F9 and use Odoo in the browser.")
      end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end
      dap.listeners.before.disconnect["dapui"] = function() dapui.close() end

      local sign = function(name, text, hl)
        vim.fn.sign_define(
          name,
          { text = text, texthl = hl, linehl = name == "DapStopped" and "Visual" or "", numhl = "" }
        )
      end
      sign("DapBreakpoint", "●", "DiagnosticError")
      sign("DapBreakpointCondition", "◆", "DiagnosticWarn")
      sign("DapLogPoint", "◉", "DiagnosticInfo")
      sign("DapStopped", "▶", "DiagnosticOk")
      sign("DapBreakpointRejected", "○", "Comment")
    end,
  },
}
