return {
  "okuuva/auto-save.nvim",
  -- keep lazy triggers for actual saving behavior
  event = { "InsertLeave", "TextChanged" },
  -- ensure the toggle command exists even before the plugin fully loads
  cmd = "ASToggle",

  -- define the keymap eagerly so which-key can see it, and notify on toggle
  init = function()
    vim.keymap.set("n", "<leader>ue", function()
      vim.cmd("ASToggle")

      -- read current state from the plugin (if loaded by the toggle)
      local enabled = false
      local ok, autosave = pcall(require, "auto-save")
      if ok and type(autosave.is_enabled) == "function" then
        enabled = autosave.is_enabled()
      end

      local msg = enabled and "AutoSave enabled" or "AutoSave disabled"
      local level = enabled and vim.log.levels.INFO or vim.log.levels.WARN

      -- prefer nvim-notify if present, otherwise fall back to vim.notify
      local ok_notify, notify = pcall(require, "notify")
      if ok_notify then
        notify(msg, level, { title = "AutoSave" })
      else
        vim.notify(msg, level, { title = "AutoSave" })
      end
    end, { desc = "Toggle Autosave" })
  end,

  -- remove the `keys = {...}` block; the eager mapping above replaces it

  opts = {
    debounce_delay = 1000, -- 1s: gentle on watchers/formatters
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost", "QuitPre", "VimSuspend" },
      defer_save = { "InsertLeave", "TextChanged" },
      cancel_deferred_save = { "InsertEnter" },
    },
    -- Skip special/ephemeral buffers & UIs
    condition = function(buf)
      local bt = vim.bo[buf].buftype
      local ft = vim.bo[buf].filetype
      if bt ~= "" then
        return false
      end
      local excluded = {
        "gitcommit",
        "TelescopePrompt",
        "neo-tree",
        "lazy",
        "lazygit",
        "oil",
        "toggleterm",
        "alpha",
        "dashboard",
        "Outline",
        "prompt",
      }
      return not vim.tbl_contains(excluded, ft)
    end,
    -- Avoid extra autocmd noise when a formatter also runs on save:
    noautocmd = false,
  },
}
