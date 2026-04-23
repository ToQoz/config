local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

config.automatically_reload_config = true
config.check_for_updates = false

config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	"Noto Color Emoji",
	"Symbols Nerd Font Mono",
})

config.line_height = 1.2
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20

config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
-- config.use_fancy_tab_bar = false

config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false

config.enable_kitty_keyboard = true
config.use_ime = true
-- for macSKK's C-j: SHIFT (default) -> SHIFT|CTRL
config.macos_forward_to_ime_modifier_mask = "SHIFT|CTRL"

config.color_scheme = "Catppuccin Mocha"

-- ----------------------------------------------------------
-- Keys
-- ----------------------------------------------------------
config.keys = {
	-- Disable C-j for macSKK
	{
		key = "j",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},

	-- Disable CMD+Q to prevent accidental quit.
	{
		key = "q",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},

	-- Command palette
	{
		key = "p",
		mods = "CMD|SHIFT",
		action = act.ActivateCommandPalette,
	},
}

return config
