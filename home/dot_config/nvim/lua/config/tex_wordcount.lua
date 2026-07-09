-- ~/.config/nvim/lua/config/tex_wordcount.lua

local M = {}

local project_cache = {}
local project_timers = {}

local selection_cache = {}
local selection_timers = {}

local function is_tex(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "tex"
end

local function has_vimtex_wordcount()
  return vim.fn.exists("*vimtex#misc#wordcount") == 1
end

local function is_visual_mode()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

local function close_timer(timer)
  if timer then
    timer:stop()
    timer:close()
  end
end

local function parse_texcount_output(stdout)
  if not stdout then
    return nil
  end

  return tonumber(stdout:match("(%d+)"))
end

local function get_visual_text(bufnr)
  local mode = vim.fn.mode()

  if not is_visual_mode() then
    return nil, nil
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  local srow, scol = start_pos[2], start_pos[3]
  local erow, ecol = end_pos[2], end_pos[3]

  if srow == 0 or erow == 0 then
    return nil, nil
  end

  if srow > erow or (srow == erow and scol > ecol) then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end

  local changedtick = vim.b[bufnr].changedtick
  local key = table.concat({
    bufnr,
    changedtick,
    mode,
    srow,
    scol,
    erow,
    ecol,
  }, ":")

  -- Visual line mode: count whole selected lines.
  if mode == "V" then
    local lines = vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, false)
    return table.concat(lines, "\n"), key
  end

  -- Visual block mode: approximate as rectangular byte columns.
  if mode == "\22" then
    local lines = vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, false)
    local selected = {}

    for _, line in ipairs(lines) do
      table.insert(selected, string.sub(line, scol, ecol))
    end

    return table.concat(selected, "\n"), key
  end

  -- Visual character mode: count the exact selected text.
  local lines = vim.api.nvim_buf_get_text(bufnr, srow - 1, scol - 1, erow - 1, ecol, {})

  return table.concat(lines, "\n"), key
end

local function count_selection_with_texcount(bufnr, key, text)
  if text == nil or text:match("^%s*$") then
    selection_cache[bufnr] = {
      key = key,
      value = "sel: 0 words",
      pending = false,
    }
    vim.cmd("redrawstatus")
    return
  end

  if vim.fn.executable("texcount") == 0 then
    selection_cache[bufnr] = {
      key = key,
      value = "sel: texcount missing",
      pending = false,
    }
    vim.cmd("redrawstatus")
    return
  end

  -- TeXcount reads from stdin when the final argument is "-".
  vim.system({ "texcount", "-nosub", "-sum", "-q", "-1", "-" }, {
    stdin = text,
    text = true,
  }, function(obj)
    local count = parse_texcount_output(obj.stdout)

    vim.schedule(function()
      local current = selection_cache[bufnr]

      if current and current.key == key then
        if count then
          current.value = "sel: " .. count .. " words"
        else
          current.value = "sel: ? words"
        end

        current.pending = false
        vim.cmd("redrawstatus")
      end
    end)
  end)
end

local function update_selection(bufnr, key, text)
  close_timer(selection_timers[bufnr])

  selection_cache[bufnr] = {
    key = key,
    value = "sel: counting...",
    pending = true,
  }

  selection_timers[bufnr] = vim.uv.new_timer()

  selection_timers[bufnr]:start(150, 0, function()
    close_timer(selection_timers[bufnr])
    selection_timers[bufnr] = nil

    vim.schedule(function()
      count_selection_with_texcount(bufnr, key, text)
    end)
  end)
end

function M.update_project(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not is_tex(bufnr) or not has_vimtex_wordcount() then
    return
  end

  close_timer(project_timers[bufnr])

  project_timers[bufnr] = vim.uv.new_timer()

  project_timers[bufnr]:start(750, 0, function()
    close_timer(project_timers[bufnr])
    project_timers[bufnr] = nil

    vim.schedule(function()
      if not is_tex(bufnr) or not has_vimtex_wordcount() then
        return
      end

      local ok, count = pcall(vim.api.nvim_buf_call, bufnr, function()
        return vim.fn["vimtex#misc#wordcount"]({
          detailed = 0,
          count_letters = 0,
        })
      end)

      if ok and count then
        project_cache[bufnr] = tostring(count) .. " words"
      else
        project_cache[bufnr] = ""
      end

      vim.cmd("redrawstatus")
    end)
  end)
end

function M.status()
  local bufnr = vim.api.nvim_get_current_buf()

  if not is_tex(bufnr) then
    return ""
  end

  if is_visual_mode() then
    local text, key = get_visual_text(bufnr)

    if not text or not key then
      return project_cache[bufnr] or ""
    end

    local cached = selection_cache[bufnr]

    if cached and cached.key == key then
      return cached.value
    end

    update_selection(bufnr, key, text)
    return "sel: counting..."
  end

  if not project_cache[bufnr] then
    M.update_project(bufnr)
    return "counting..."
  end

  return project_cache[bufnr]
end

vim.api.nvim_create_autocmd({
  "BufEnter",
  "BufWritePost",
  "TextChanged",
  "TextChangedI",
}, {
  pattern = "*.tex",
  callback = function(args)
    M.update_project(args.buf)
  end,
})

vim.api.nvim_create_autocmd({
  "ModeChanged",
  "CursorMoved",
  "CursorMovedI",
}, {
  pattern = "*.tex",
  callback = function()
    vim.cmd("redrawstatus")
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    close_timer(project_timers[args.buf])
    close_timer(selection_timers[args.buf])

    project_cache[args.buf] = nil
    selection_cache[args.buf] = nil
    project_timers[args.buf] = nil
    selection_timers[args.buf] = nil
  end,
})

return M
