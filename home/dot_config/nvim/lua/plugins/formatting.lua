return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
      -- Python: Ruff does both organize-imports and format
      python = { "ruff_organize_imports", "ruff_format" },

      -- .gitignore
      gitignore = { "prettierd" },
    })
  end,
}
