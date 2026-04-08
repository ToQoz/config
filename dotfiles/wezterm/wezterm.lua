local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

config.automatically_reload_config = true
config.check_for_updates = false

config.leader = {
	key = "t",
	mods = "CTRL",
	timeout_milliseconds = 1000,
}

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
-- Helpers
-- ----------------------------------------------------------
local function basename(s)
	if not s or s == "" then
		return ""
	end
	return s:gsub(".*[/\\]", "")
end

local function pane_cwd(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd then
		return nil
	end

	-- newer versions return Url object-ish data
	if type(cwd) == "userdata" or type(cwd) == "table" then
		local file_path = cwd.file_path
		if file_path and file_path ~= "" then
			return file_path
		end
		local path = cwd.path
		if path and path ~= "" then
			return path
		end
		local tostringed = tostring(cwd)
		if tostringed and tostringed ~= "" then
			return tostringed
		end
	end

	if type(cwd) == "string" then
		return cwd
	end

	return nil
end

local function current_pane_title(tab)
	local pane = tab.active_pane
	if not pane then
		return ""
	end

	local title = pane.title
	if title and title ~= "" then
		return title
	end

	local cwd = pane_cwd(pane)
	if cwd then
		return basename(cwd)
	end

	return ""
end

-- ----------------------------------------------------------
-- Status / Tab Title
-- ----------------------------------------------------------
wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
	local index = tab.tab_index + 1
	local title = tab.tab_title
	if not title or title == "" then
		title = current_pane_title(tab)
	end
	if title == "" then
		title = "shell"
	end

	local text = string.format(" %d %s ", index, title)
	return wezterm.truncate_right(text, max_width)
end)

-- ----------------------------------------------------------
-- Custom events
-- ----------------------------------------------------------
wezterm.on("rename-current-tab", function(window, pane)
	window:perform_action(
		act.PromptInputLine({
			description = "Rename tab",
			action = wezterm.action_callback(function(win, _, line)
				if line and line ~= "" then
					win:active_tab():set_title(line)
				end
			end),
		}),
		pane
	)
end)

wezterm.on("save-scrollback", function(window, pane)
	window:perform_action(
		act.PromptInputLine({
			description = "Save scrollback to file",
			initial_value = os.getenv("HOME") .. "/.wezterm.capture",
			action = wezterm.action_callback(function(_, p, line)
				if not line or line == "" then
					return
				end

				local text = p:get_lines_as_text(32768)
				local f, err = io.open(line, "w")
				if not f then
					wezterm.log_error("failed to write scrollback: " .. tostring(err))
					return
				end
				f:write(text)
				f:close()
			end),
		}),
		pane
	)
end)

wezterm.on("split-and-run", function(window, pane)
	window:perform_action(
		act.PromptInputLine({
			description = "Run command in a new split",
			action = wezterm.action_callback(function(win, p, line)
				if not line or line == "" then
					return
				end

				local cwd = pane_cwd(p)
				win:perform_action(
					act.SplitVertical({
						cwd = cwd,
						args = { os.getenv("SHELL") or "/bin/zsh", "-lc", line },
					}),
					p
				)
			end),
		}),
		pane
	)
end)

wezterm.on("move-pane-to-new-tab", function(window, pane)
	pane:move_to_new_tab()
end)

wezterm.on("kill-pane-no-confirm", function(window, pane)
	window:perform_action(act.CloseCurrentPane({ confirm = false }), pane)
end)

wezterm.on("kill-tab-with-confirm", function(window, pane)
	window:perform_action(act.CloseCurrentTab({ confirm = true }), pane)
end)

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
	-- Reload config
	{
		key = "r",
		mods = "LEADER|CTRL",
		action = act.ReloadConfiguration,
	},

	-- New tab (tmux new-window 相当)
	{
		key = "c",
		mods = "LEADER",
		action = act.SpawnTab("CurrentPaneDomain"),
	},

	-- Split: keep current pane domain / cwd は WezTerm 側で可能な限り継承
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

	-- Pane move like Vim
	{
		key = "h",
		mods = "LEADER",
		action = act.ActivatePaneDirection("Left"),
	},
	{
		key = "j",
		mods = "LEADER",
		action = act.ActivatePaneDirection("Down"),
	},
	{
		key = "k",
		mods = "LEADER",
		action = act.ActivatePaneDirection("Up"),
	},
	{
		key = "l",
		mods = "LEADER",
		action = act.ActivatePaneDirection("Right"),
	},

	-- Resize
	{
		key = "h",
		mods = "LEADER|CTRL",
		action = act.AdjustPaneSize({ "Left", 6 }),
	},
	{
		key = "j",
		mods = "LEADER|CTRL",
		action = act.AdjustPaneSize({ "Down", 6 }),
	},
	{
		key = "k",
		mods = "LEADER|CTRL",
		action = act.AdjustPaneSize({ "Up", 6 }),
	},
	{
		key = "l",
		mods = "LEADER|CTRL",
		action = act.AdjustPaneSize({ "Right", 6 }),
	},

	-- Tab move ~= tmux swap-window H/L
	{
		key = "H",
		mods = "LEADER|SHIFT",
		action = act.MoveTabRelative(-1),
	},
	{
		key = "L",
		mods = "LEADER|SHIFT",
		action = act.MoveTabRelative(1),
	},

	-- Tab / pane helpers
	{
		key = "w",
		mods = "LEADER",
		action = act.ShowTabNavigator,
	},
	{
		key = "s",
		mods = "LEADER",
		action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }),
	},
	{
		key = "1",
		mods = "LEADER",
		action = act.EmitEvent("move-pane-to-new-tab"),
	},

	-- Kill
	{
		key = "K",
		mods = "LEADER|SHIFT",
		action = act.EmitEvent("kill-tab-with-confirm"),
	},
	{
		key = "P",
		mods = "LEADER|SHIFT",
		action = act.EmitEvent("kill-pane-no-confirm"),
	},

	-- Copy mode / paste
	{
		key = "y",
		mods = "LEADER",
		action = act.ActivateCopyMode,
	},
	{
		key = "p",
		mods = "LEADER",
		action = act.PasteFrom("Clipboard"),
	},

	-- Prompt-like helpers
	{
		key = "P",
		mods = "LEADER",
		action = act.EmitEvent("save-scrollback"),
	},
	{
		key = "e",
		mods = "LEADER",
		action = act.EmitEvent("split-and-run"),
	},
	{
		key = ",",
		mods = "LEADER",
		action = act.EmitEvent("rename-current-tab"),
	},

	-- optional: command palette
	{
		key = "p",
		mods = "CMD|SHIFT",
		action = act.ActivateCommandPalette,
	},
}

-- ----------------------------------------------------------
-- Copy mode (vi-like)
-- ----------------------------------------------------------
config.key_tables = {
	copy_mode = {
		-- visual mode
		{ key = "v", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
		{ key = "V", action = wezterm.action.CopyMode({ SetSelectionMode = "Line" }) },
		-- move
		{ key = "h", action = wezterm.action.CopyMode("MoveLeft") },
		{ key = "j", action = wezterm.action.CopyMode("MoveDown") },
		{ key = "k", action = wezterm.action.CopyMode("MoveUp") },
		{ key = "l", action = wezterm.action.CopyMode("MoveRight") },
		{ key = "0", action = wezterm.action.CopyMode("MoveToStartOfLine") },
		{ key = "$", action = wezterm.action.CopyMode("MoveToEndOfLineContent") },
		{ key = "d", mods = "CTRL", action = wezterm.action.CopyMode("PageDown") },
		{ key = "u", mods = "CTRL", action = wezterm.action.CopyMode("PageUp") },
		-- search
		{ key = "/", action = wezterm.action.Search({ CaseSensitiveString = "" }) },
		{ key = "n", action = wezterm.action.CopyMode("NextMatch") },
		{ key = "N", action = wezterm.action.CopyMode("PriorMatch") },
		-- yank
		{
			key = "y",
			action = act.Multiple({
				act.CopyTo("ClipboardAndPrimarySelection"),
				act.CopyMode("Close"),
			}),
		},
		-- exit
		{ key = "q", action = wezterm.action.CopyMode("Close") },
		{ key = "Escape", action = act.CopyMode("Close") },
	},
}

return config
