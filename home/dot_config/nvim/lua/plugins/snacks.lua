return {
  {
    "folke/snacks.nvim",
    opts = {
      words = {
        enabled = true,
      },
      picker = {
        hidden = true, -- show files starting with “.”
        sources = {
          files = {
            hidden = true,
            ignored = true,
          },
        },
      },
    },
  },
}
