local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local ok, colors = pcall(dofile, configHome .. "/hypr/colors.local.lua")
if not ok or type(colors) ~= "table" then
    colors = require("colors")
end
local userPrefs = require("local_prefs")
-- Veyra-managed values written by Veyra Settings act as a fallback, so the
-- user's own userprefs.local.lua always wins.
local veyraPrefs = require("veyra_prefs")

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 2,
		border_size = 4,
		["col.active_border"] = colors.accent_alpha,
		["col.inactive_border"] = colors.border_alpha,
		allow_tearing = true, -- only applies to windows that request it (games)
		layout = "dwindle",
	},
	group = {
		groupbar = {
			height = 16,
			indicator_gap = 8,
			["col.active"] = colors.accent_alpha,
			["col.inactive"] = colors.border_alpha,
			text_color = colors.accent_alpha,
			text_color_inactive = colors.border_alpha,
			font_size = 11,
			font_family = "Geist",
			font_weight_active = "bold",
			blur = true,
		},
	},
	decoration = {
		rounding = 26,
		rounding_power = 2,
		active_opacity = 1,
		inactive_opacity = 1,
		blur = {
			enabled = true,
			size = 6,
			passes = 1,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
			noise = 0.0117,
			contrast = 0.8916,
			brightness = 0.8172,
			vibrancy = 0.1696,
			vibrancy_darkness = 0.0,
			popups = false,
			popups_ignorealpha = 0.2,
			input_methods = true,
			special = false,
		},
		shadow = {
			enabled = false,
			range = 11,
			render_power = 4,
			color = colors.shadow,
		},
	},
	dwindle = {
		preserve_split = true,
		smart_split = false,
		smart_resizing = true,
		force_split = 2,
		default_split_ratio = 1,
		permanent_direction_override = false,
		split_width_multiplier = 1,
		use_active_for_splits = true,
		split_bias = 0,
		precise_mouse_move = false,
	},
	master = {
		new_status = "master",
		mfact = 0.55,
		orientation = "left",
		allow_small_split = false,
		smart_resizing = true,
		new_on_top = false,
		new_on_active = "none",
		drop_at_cursor = true,
		always_keep_position = false,
		focus_master_on_close = false,
		slave_count_for_center_master = 2,
		center_master_fallback = "left",
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		initial_workspace_tracking = 0,
	},
	cursor = {
		inactive_timeout = 0,
		warp_on_change_workspace = 1,
		no_warps = false,
		no_hardware_cursors = 0,
	},
	input = {
		kb_layout = userPrefs.keyboard_layout or veyraPrefs.keyboard_layout or os.getenv("VEYRA_KEYBOARD_LAYOUT") or "us",
		kb_options = userPrefs.keyboard_options or veyraPrefs.keyboard_options or os.getenv("VEYRA_KEYBOARD_OPTIONS") or "grp:alt_shift_toggle",
		follow_mouse = 1,
		sensitivity = 0,
		accel_profile = "adaptive",
		repeat_rate = 40,
		repeat_delay = 400,
		numlock_by_default = true,
		natural_scroll = false,
		scroll_factor = 1.3,
		left_handed = false,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			disable_while_typing = true,
		},
	},
	xwayland = {
		force_zero_scaling = true,
	},
	animations = {
		enabled = true,
	},
})
