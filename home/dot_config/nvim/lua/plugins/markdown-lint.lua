return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      local lint = require("lint")

      -- make sure the executable is markdownlint-cli2
      lint.linters.markdownlint.cmd = "markdownlint-cli2"

      -- keep any existing args and add disables
      lint.linters.markdownlint.args = vim.list_extend(lint.linters.markdownlint.args or {}, {
        "--disable",
        "MD013",
        "--disable",
        "MD033",
        "--disable",
        "MD024",
      })

      -- IMPORTANT: use the linter *name* here
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = { "markdownlint" }
    end,
  },
}
