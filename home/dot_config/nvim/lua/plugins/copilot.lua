return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        copilot = {
          -- Keep Copilot disabled for TeX while allowing the native LSP to
          -- attach to every other filetype supported by Neovim.
          root_dir = function(bufnr, on_dir)
            if vim.bo[bufnr].filetype == "tex" then
              return
            end

            on_dir(vim.fs.root(bufnr, ".git") or vim.fn.getcwd())
          end,
        },
      },
    },
  },
}
