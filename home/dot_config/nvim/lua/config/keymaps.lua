-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- in insert mode, Ctrl+Right to jump forward by one word
vim.keymap.set("i", "<C-l>", "<C-o>e", {
  noremap = true,
  silent = true,
  desc = "Insert: next word",
})

-- in insert mode, Ctrl+Left to jump backward by one word
vim.keymap.set("i", "<C-h>", "<C-o>b", {
  noremap = true,
  silent = true,
  desc = "Insert: previous word",
})

-- yank all files in the same folder as the current buffer (with headers) to system clipboard
vim.keymap.set("n", "<leader>fy", function()
  -- directory of the current file
  local dir = vim.fn.expand("%:p:h")
  -- if the buffer has no file (e.g. [No Name]), fall back to cwd
  if dir == "" then
    dir = vim.fn.getcwd()
  end

  local files = vim.fn.readdir(dir)
  local out = {}

  for _, name in ipairs(files) do
    local path = dir .. "/" .. name
    if vim.fn.isdirectory(path) == 0 then
      table.insert(out, "=== " .. name .. " ===")
      for _, line in ipairs(vim.fn.readfile(path)) do
        table.insert(out, line)
      end
      table.insert(out, "")
    end
  end

  vim.fn.setreg("+", table.concat(out, "\n"))
  print("📋 Yanked " .. #out .. " lines from " .. #files .. " files in: " .. dir)
end, { desc = "fy: Yank all files in buffer’s folder to + register" })

-- Append the first diagnostic on the current line to the system clipboard
vim.keymap.set("n", "<leader>xa", function()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diags = vim.diagnostic.get(0, { lnum = row })
  if #diags > 0 then
    local msg = (diags[1].message or ""):gsub("%s+", " ")
    local current_clipboard = vim.fn.getreg("+")
    local new_clipboard = current_clipboard ~= "" and (current_clipboard .. "\n" .. msg) or msg
    vim.fn.setreg("+", new_clipboard) -- append to clipboard (+)
    vim.notify("Appended diagnostic: " .. msg, vim.log.levels.INFO)
  else
    vim.notify("No diagnostics on this line", vim.log.levels.WARN)
  end
end, { desc = "Append diagnostic on line to clipboard" })

-- Send current line + diagnostics on that line to system clipboard
vim.keymap.set("n", "<leader>xy", function()
  local bufnr = 0
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- current line text
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  line = line:gsub("%s+$", "")

  -- diagnostics on the line
  local diags = vim.diagnostic.get(bufnr, { lnum = row })
  if #diags == 0 then
    vim.notify("No diagnostics on this line", vim.log.levels.WARN)
    return
  end

  -- collect all diagnostics
  local parts = {}
  for _, d in ipairs(diags) do
    local msg = (d.message or ""):gsub("%s+", " ")
    if msg ~= "" then
      table.insert(parts, msg)
    end
  end

  local combined = line .. "\n" .. table.concat(parts, "\n")

  -- overwrite clipboard (+)
  vim.fn.setreg("+", combined)

  vim.notify("Copied line + diagnostics to clipboard", vim.log.levels.INFO)
end, { desc = "Copy current line + diagnostics to clipboard" })

