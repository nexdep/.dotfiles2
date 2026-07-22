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

-- IMPORTANT:
-- Define config.keys only once. Assigning another table to config.keys later
-- replaces all of the bindings defined here.
config.keys = {
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

-- ============================================================================
-- FINISH
-- ============================================================================

return config
