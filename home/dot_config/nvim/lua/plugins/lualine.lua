return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local tex_wordcount = require("config.tex_wordcount")

      require("lualine").setup({
        options = {
          refresh = {
            statusline = 250,
          },
        },

        sections = {
          lualine_x = {
            {
              tex_wordcount.status,
              cond = function()
                return vim.bo.filetype == "tex"
              end,
            },
            "encoding",
            "filetype",
          },
        },
      })
    end,
  },
}
