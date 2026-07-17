return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        exclude = { "vue", "tex", "plaintex" },
      },
      servers = {
        texlab = {
          settings = {
            texlab = {
              diagnostics = {
                ignoredPatterns = {
                  "Unused label",
                },
              },
              inlayHints = {
                labelReferences = false,
              },
            },
          },
        },
      },
    },
  },
}
