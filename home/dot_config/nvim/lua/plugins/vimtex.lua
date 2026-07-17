return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  -- tag = "v2.15", -- uncomment to pin to a specific release
  init = function()
    -- VimTeX configuration goes here, e.g.
    vim.g.vimtex_view_method = "zathura"
    -- These are Vim regexes. Match the log line(s) you want to hide.
    vim.g.vimtex_quickfix_ignore_filters = {
      [[Underfull \\hbox]], -- hide underfull hbox warnings
      -- [[Overfull \\hbox]], -- (optional) hide overfull hbox warnings too
      -- [[Underfull \\vbox]], -- (optional) hide underfull vbox warnings too
    }
    vim.g.vimtex_syntax_custom_cmds = {
      {
        name = "texttt",
        argspell = false,
      },
    }
  end,
}
