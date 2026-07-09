return {
  {
    "jhofscheier/ltex-utils.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      dictionary = {
        path = vim.fn.stdpath("config") .. "/ltex/",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jhofscheier/ltex-utils.nvim",
    },
    opts = {
      servers = {
        ltex_plus = {
          cmd = { "ltex-ls-plus" },
          filetypes = { "tex", "bib", "markdown", "text" },

          on_attach = function(_, bufnr)
            require("ltex-utils").on_attach(bufnr)
          end,

          settings = {
            ltex = {
              language = "en-US",
              checkFrequency = "save",
              diagnosticSeverity = "information",
              completionEnabled = false,

              dictionary = {
                ["en-US"] = {},
              },

              disabledRules = {
                ["en-US"] = {},
              },

              hiddenFalsePositives = {
                ["en-US"] = {},
              },
            },
          },
        },
      },
    },
  },
}
