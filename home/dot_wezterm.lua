-- ============================================================================
-- WezTerm configuration
-- Locations: ~/.wezterm.lua on Linux/WSL, %USERPROFILE%\.wezterm.lua on Windows
-- ============================================================================

local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows", 1, true) ~= nil
local wsl_home_prog = { "wsl.exe", "--cd", "~" }

-- ============================================================================
-- FONT AND COLOR THEME
-- ============================================================================

local symbol_font = "Noto Sans Symbols"
if is_windows then
  symbol_font = {
    family = "Segoe UI Symbol",
    assume_emoji_presentation = false,
  }
end

config.font = wezterm.font_with_fallback {
  "UbuntuMono Nerd Font Mono",
  symbol_font,
}

config.font_size = 10.0

-- Built-in light color scheme.
config.color_scheme = "OneHalfLight"

-- ============================================================================
-- INITIAL WINDOW SIZE
-- ============================================================================

-- Dimensions are measured in terminal character cells.
config.initial_cols = 120
config.initial_rows = 32

-- Small amount of space around the terminal content.
config.window_padding = {
  left = 3,
  right = 3,
  top = 0,
  bottom = 0,
}

-- ============================================================================
-- WINDOW APPEARANCE
-- ============================================================================

-- Put the minimize, maximize and close buttons in the tab bar.
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

config.integrated_title_buttons = {
  "Hide",
  "Maximize",
  "Close",
}

config.integrated_title_button_alignment = "Right"
config.integrated_title_button_style = is_windows and "Windows" or "Gnome"

-- Do not ask for confirmation when closing the complete window.
config.window_close_confirmation = "NeverPrompt"

-- ============================================================================
-- TAB BAR
-- ============================================================================

config.use_fancy_tab_bar = true

-- Hide the tab bar, including the integrated window buttons, when only one tab
-- exists.
config.hide_tab_bar_if_only_one_tab = true

-- This option is currently documented as nightly-build-only.
config.show_close_tab_button_in_tabs = true

-- ============================================================================
-- DEFAULT SHELL AND LAUNCH MENU
-- ============================================================================

-- Native Linux uses WezTerm's default login-shell behavior. On Windows, start
-- the default WSL distribution in its default user's home and offer both WSL
-- and PowerShell launchers.
if is_windows then
  config.default_prog = wsl_home_prog

  config.launch_menu = {
    {
      label = "WSL — Default",
      args = wsl_home_prog,
    },

    {
      label = "PowerShell 7",
      args = { "pwsh.exe" },
    },
  }
end

-- ============================================================================
-- KEYBOARD CONFIGURATION
-- ============================================================================

-- Keep WezTerm's normal shortcuts enabled.
--
-- Setting this to true disables every built-in shortcut, meaning that you
-- would need to manually recreate new-tab, close-tab, font-size and other
-- standard key bindings.
config.disable_default_key_bindings = false

-- Match tmux's Ctrl-a prefix. Press Ctrl-a twice to send a literal Ctrl-a to
-- the program in the active pane (including a manually launched tmux).
config.leader = {
  key = "a",
  mods = "CTRL",
  timeout_milliseconds = 1000,
}

-- Build a command in the active pane's domain and working directory. Windows
-- local panes launch WSL through wsl.exe, so pass the Linux path to WSL itself
-- rather than asking Windows to use it as the process working directory.
local function command_in_current_directory(pane)
  local cwd = pane:get_current_working_dir()
  local cwd_path = cwd and cwd.file_path or nil
  local cwd_is_windows_path = cwd_path
    and (cwd_path:match("^/%a:/") or cwd_path:match("^%a:/"))
  local command = {
    domain = "CurrentPaneDomain",
  }

  if is_windows and pane:get_domain_name() == "local" then
    if cwd_path and not cwd_is_windows_path then
      command.args = { "wsl.exe", "--cd", cwd_path }
    else
      command.args = wsl_home_prog
    end
  elseif cwd_path then
    command.cwd = cwd_path
  end

  return command
end

-- tmux's Prefix+v inserts a window immediately after the current one. The mux
-- spawn API waits for the new tab to exist, so MoveTab can target it reliably.
local spawn_tab_to_right = wezterm.action_callback(function(window, pane)
  local mux_window = window:mux_window()
  local active_index = 0

  for _, tab_info in ipairs(mux_window:tabs_with_info()) do
    if tab_info.is_active then
      active_index = tab_info.index
      break
    end
  end

  local new_tab, new_pane = mux_window:spawn_tab(command_in_current_directory(pane))
  new_tab:activate()
  window:perform_action(act.MoveTab(active_index + 1), new_pane)
end)

-- Split in the active pane's working directory.
local function split_in_current_directory(direction)
  return wezterm.action_callback(function(window, pane)
    local command = command_in_current_directory(pane)

    window:perform_action(
      act.SplitPane({
        direction = direction,
        command = command,
      }),
      pane
    )
  end)
end

-- Prefix+c deliberately starts in the shell home, matching the final tmux
-- binding. Choose the command at keypress time because CurrentPaneDomain may
-- be an SSH domain: wsl.exe is valid only in WezTerm's local Windows domain.
local spawn_home_tab = wezterm.action_callback(function(window, pane)
  local command = {
    domain = "CurrentPaneDomain",
  }

  if pane:get_domain_name() == "local" then
    if is_windows then
      command.args = wsl_home_prog
    else
      command.cwd = wezterm.home_dir
    end
  else
    -- A local home path cannot be reused in a remote domain. Let the remote
    -- shell resolve its own home, then replace the wrapper with a login shell.
    command.args = { "/bin/sh", "-lc", 'cd && exec "${SHELL:-/bin/sh}" -l' }
  end

  window:perform_action(act.SpawnCommandInNewTab(command), pane)
end)

-- IMPORTANT:
-- Define config.keys only once. Assigning another table to config.keys later
-- replaces all of the bindings defined here.
config.keys = {
  -- --------------------------------------------------------------------------
  -- tmux-style panes, tabs and copy mode
  -- --------------------------------------------------------------------------

  -- Send the leader key through to the active program.
  {
    key = "a",
    mods = "LEADER|CTRL",
    action = act.SendKey({ key = "a", mods = "CTRL" }),
  },

  -- Split right/below in the current pane's domain and working directory.
  {
    key = "|",
    mods = "LEADER|SHIFT",
    action = split_in_current_directory("Right"),
  },
  {
    key = "-",
    mods = "LEADER",
    action = split_in_current_directory("Down"),
  },

  -- Navigate panes with the same Ctrl-a, Ctrl-h/j/k/l chords as tmux.
  {
    key = "h",
    mods = "LEADER|CTRL",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "LEADER|CTRL",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "LEADER|CTRL",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "LEADER|CTRL",
    action = act.ActivatePaneDirection("Right"),
  },

  -- Close a pane without prompting and reload this configuration.
  {
    key = "x",
    mods = "LEADER",
    action = act.CloseCurrentPane({ confirm = false }),
  },
  {
    key = "r",
    mods = "LEADER",
    action = act.ReloadConfiguration,
  },

  -- Create tabs using tmux's home/current-directory distinction.
  {
    key = "c",
    mods = "LEADER",
    action = spawn_home_tab,
  },
  {
    key = "v",
    mods = "LEADER",
    action = spawn_tab_to_right,
  },

  -- Switch tabs without the leader, like tmux's Alt-h/Alt-l bindings.
  {
    key = "h",
    mods = "ALT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "l",
    mods = "ALT",
    action = act.ActivateTabRelative(1),
  },

  -- Enter WezTerm's vi-style copy mode using tmux's Prefix+[ chord.
  {
    key = "[",
    mods = "LEADER",
    action = act.ActivateCopyMode,
  },

  -- --------------------------------------------------------------------------
  -- Clipboard
  -- --------------------------------------------------------------------------

  -- Standard terminal paste.
  {
    key = "v",
    mods = "CTRL|SHIFT",
    action = act.PasteFrom("Clipboard"),
  },

  -- Standard terminal copy.
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = act.CopyTo("Clipboard"),
  },

  -- --------------------------------------------------------------------------
  -- Launchers
  -- --------------------------------------------------------------------------

  -- Open the standard launcher.
  {
    key = "o",
    mods = "ALT",
    action = act.ShowLauncher,
  },

  -- Open the launcher directly in fuzzy-search mode.
  {
    key = "p",
    mods = "ALT",
    action = act.ShowLauncherArgs({
      flags = table.concat({
        "FUZZY",
        "LAUNCH_MENU_ITEMS",
        "DOMAINS",
        "TABS",
        "WORKSPACES",
        "COMMANDS",
      }, "|"),
    }),
  },
}

-- WezTerm's default copy table already provides v for cell selection and y
-- for copying the selection and exiting. Extend rather than replace it so the
-- rest of the native vi-style controls remain available.
if wezterm.gui then
  local copy_mode = wezterm.gui.default_key_tables().copy_mode
  local copy_current_line = act.Multiple({
    act.CopyMode({ SetSelectionMode = "Line" }),
    act.CopyTo("ClipboardAndPrimarySelection"),
    act.CopyMode("MoveToScrollbackBottom"),
    act.CopyMode("Close"),
  })

  -- Accept both representations emitted for Shift-y under the supported
  -- keyboard mapping modes.
  table.insert(copy_mode, {
    key = "Y",
    mods = "NONE",
    action = copy_current_line,
  })
  table.insert(copy_mode, {
    key = "Y",
    mods = "SHIFT",
    action = copy_current_line,
  })

  config.key_tables = {
    copy_mode = copy_mode,
  }
end

-- ============================================================================
-- FINISH
-- ============================================================================

return config
