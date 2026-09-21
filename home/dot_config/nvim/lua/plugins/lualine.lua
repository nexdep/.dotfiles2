return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local tex_wordcount = require("config.tex_wordcount")

      local function is_visual()
        return vim.fn.mode():match("[vV\22]") ~= nil
      end

      local function selection_size()
        local lines = math.abs(vim.fn.line(".") - vim.fn.line("v")) + 1
        local cols = math.abs(vim.fn.virtcol(".") - vim.fn.virtcol("v")) + 1
        return string.format("%d lines, %d cols", lines, cols)
      end

      require("lualine").setup({
        options = {
          refresh = {
            statusline = 250,
          },
        },

        sections = {
          lualine_c = {
            {
              "filename",
              path = 2,
            },
          },
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
          lualine_y = {
            { selection_size, cond = is_visual },
            "progress",
          },
        },
      })
    end,
  },
}
