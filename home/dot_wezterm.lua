-- ============================================================================
-- WezTerm configuration
-- Locations: ~/.wezterm.lua on Linux/WSL, %USERPROFILE%\.wezterm.lua on Windows
-- ============================================================================

local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows", 1, true) ~= nil

-- ============================================================================
-- FONT AND COLOR THEME
-- ============================================================================

config.font = wezterm.font("UbuntuMono Nerd Font Mono")

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
-- the default WSL distribution and offer both WSL and PowerShell launchers.
if is_windows then
  config.default_prog = {
    "wsl.exe",
  }

  config.launch_menu = {
    {
      label = "WSL — Default",
      args = { "wsl.exe" },
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

-- tmux's Prefix+v inserts a window immediately after the current one. WezTerm
-- normally appends new tabs, so remember the current index and move the newly
-- spawned tab into the equivalent position.
local spawn_tab_to_right = wezterm.action_callback(function(window, pane)
  local active_index = 0

  for _, tab_info in ipairs(window:mux_window():tabs_with_info()) do
    if tab_info.is_active then
      active_index = tab_info.index
      break
    end
  end

  window:perform_action(
    act.Multiple({
      act.SpawnTab("CurrentPaneDomain"),
      act.MoveTab(active_index + 1),
    }),
    pane
  )
end)

-- Prefix+c deliberately starts in the shell home, matching the final tmux
-- binding. The Windows config launches the default WSL distribution, so ask
-- wsl.exe to use the Linux home rather than the Windows user profile.
local spawn_home_tab
if is_windows then
  spawn_home_tab = act.SpawnCommandInNewTab({
    args = { "wsl.exe", "--cd", "~" },
    domain = "CurrentPaneDomain",
  })
else
  spawn_home_tab = act.SpawnCommandInNewTab({
    cwd = wezterm.home_dir,
    domain = "CurrentPaneDomain",
  })
end

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
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "-",
    mods = "LEADER",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
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
