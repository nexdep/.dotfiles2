return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
                relativePatternSupport = true,
              },
            },
          },
          settings = {
            pyright = {
              -- Hide editor-only tagged hints (such as unreachable-code graying)
              -- without suppressing normal Pyright diagnostics.
              disableTaggedHints = true,
            },
          },
        },
      },
    },
  },
}
