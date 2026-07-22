-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Keep formatting manual for every filetype. LazyVim's manual format command
-- uses `force = true`, so `<leader>cf` continues to work.
vim.g.autoformat = false

-- Keep long lines on a single screen line and scroll horizontally instead.
vim.opt.wrap = false

-- Enable Windows clipboard when running in WSL

if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "win32yank-wsl",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 0,
  }
end

-- conceal labels in LaTeX documents
vim.g.vimtex_syntax_conceal = {
  labels = 1,

  refs = 0,
  cites = 0,
  spacing = 0, -- Keep commands such as \vspace and \hfill visible.
  math_bounds = 0,
  math_delimiters = 0,
  math_fracs = 0,
  math_super_sub = 0,
  math_symbols = 0,
  sections = 0,
  styles = 0,
}
