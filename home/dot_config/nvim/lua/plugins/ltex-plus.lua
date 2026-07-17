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
          filetypes = { "tex", "bib", "markdown" },

          on_attach = function(_, bufnr)
            require("ltex-utils").on_attach(bufnr)

            local group = vim.api.nvim_create_augroup("LTeXUtilsSaveOnWrite", { clear = false })
            vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePost", {
              group = group,
              buffer = bufnr,
              callback = function(args)
                require("ltex-utils").write_settings_to_file(args.buf)
              end,
              desc = "Save ltex settings on file write",
            })
          end,

          settings = {
            ltex = {
              language = "en-US",
              checkFrequency = "save",
              diagnosticSeverity = "information",
              completionEnabled = false,

              latex = {
                commands = {
                  ["\\texttt{}"] = "dummy",
                  ["\\refeq{}"] = "dummy",
                  ["\\newacro{}"] = "dummy",
                },
              },

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
