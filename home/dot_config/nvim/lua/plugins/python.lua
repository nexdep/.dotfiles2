return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
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
