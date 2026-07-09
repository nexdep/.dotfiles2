return {
  "artemave/workspace-diagnostics.nvim",
  keys = {
    {
      "<leader>xw",
      function()
        local wd = require("workspace-diagnostics")

        for _, client in ipairs(vim.lsp.get_clients()) do
          if
            client.name == "pyright"
            or client.name == "basedpyright"
            or client.name == "ruff"
            or client.name == "ruff_lsp"
          then
            -- 0 = current buffer; plugin doesn't require a real bufnr
            wd.populate_workspace_diagnostics(client, 0)
          end
        end
      end,
      desc = "Populate workspace diagnostics (pyright + ruff)",
    },
  },
}
