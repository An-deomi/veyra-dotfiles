-- Merged keybinds: Noctalia workflow on top of veyra's Quickshell widgets.
-- Each "-- # ..." comment describes the bind below it.

local mainMod = "SUPER"
-- UWSM is optional. Enable it in userprefs.local.lua or set VEYRA_USE_UWSM=1.
local userPrefs = require("local_prefs")
local useUwsm = userPrefs.use_uwsm
if useUwsm == nil then
    useUwsm = os.getenv("VEYRA_USE_UWSM") == "1"
end
local launchPrefix = useUwsm and "uwsm app -- " or ""
local exitSessionCommand = useUwsm and "uwsm stop" or "hyprctl dispatch exit"
local calculator = "gnome-calculator"
local NUM_WORKSPACES = 10
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local defaultsHelper = configHome .. "/quickshell/Scripts/system/default_apps.py"
local hyprScripts = configHome .. "/hypr/scripts/"
local function scriptCommand(name, args)
    return string.format("%q %s", hyprScripts .. name, args)
end
local function defaultsCommand(args)
    return "python3 \"" .. defaultsHelper .. "\" " .. args
end

-- ## Applications

-- # Open Terminal
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(defaultsCommand("launch terminal")))
-- # Open Floating Terminal
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(defaultsCommand("launch terminal-floating")))
-- # Open File Manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(defaultsCommand("launch fileManager")))
-- # Open Editor
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(defaultsCommand("launch coding")))
-- # Open Calculator
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(launchPrefix .. calculator))
hl.bind("XF86Calculator", hl.dsp.exec_cmd(launchPrefix .. calculator))
-- # Open Browser
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(defaultsCommand("launch browser")))
-- # System Monitor (btop)
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(defaultsCommand("launch btop")))
-- # Pick Color
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a -n"))
-- # Toggle Hotspot
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd([[sh -c 'python3 "$HOME/.config/quickshell/Modules/ControlCenter/scripts/hotspot.py" toggle']]))

-- ## Screenshots

-- # Screenshot (Veyra widget)
hl.bind("Print", hl.dsp.exec_cmd("qs ipc call widgets toggle screenshot"))
-- # Screenshot Monitor
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("rishot monitor"))
-- # Silent Screenshot
hl.bind("CTRL + Print", hl.dsp.exec_cmd("silent-shot"))


-- ## Window Management

-- # Close Active Window
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- # Exit Hyprland
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(exitSessionCommand))
-- # Lock Screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lockScreen toggle"))
-- # Toggle Floating Mode
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
-- # Toggle Maximize Window
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = 1 }))
-- # Toggle Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- # Toggle Split Direction
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
-- # Pseudo Tiling Layout
hl.bind(mainMod .. " + CONTROL + P", hl.dsp.window.pseudo())
-- # Center Floating Window
hl.bind(mainMod .. " + CONTROL + C", hl.dsp.window.center())
-- # Pin Window on All Workspaces
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin())
-- # Minimize Window to Scratchpad
hl.bind(mainMod .. " + N", hl.dsp.window.move({ workspace = "special:minimized", silent = true }))
-- # Restore Minimized Windows
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.workspace.toggle_special("minimized"))
-- # Cycle Windows & Island Overview
local function cycleWindows()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs ipc call widgets toggle islandOverview"))
hl.bind(mainMod .. " + SHIFT + Tab", cycleWindows)

-- ## Navigation

-- # Move Focus
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

-- # Move Window Position
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

-- # Resize Active Window
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.resize({ x = 10, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.resize({ x = -10, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -10 }), { repeating = true })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 10 }), { repeating = true })

-- # Swap Window Position
hl.bind(mainMod .. " + ALT + SHIFT + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + ALT + SHIFT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + ALT + SHIFT + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + ALT + SHIFT + down", hl.dsp.window.swap({ direction = "d" }))

-- ## Workspaces

-- # Switch to Workspace / Send Window to Workspace (1..0)
for i = 1, NUM_WORKSPACES do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + CONTROL + " .. key, hl.dsp.focus({ workspace = "m~" .. i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + CONTROL + " .. key, hl.dsp.window.move({ workspace = "m~" .. i }))
end

-- # Previous / Next Workspace, Next Empty
hl.bind(mainMod .. " + CONTROL + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down", hl.dsp.focus({ workspace = "emptym" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left", hl.dsp.window.move({ workspace = "m-1" }))

-- # Scroll Through Workspaces and Monitors
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up", hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))

-- # Toggle Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special())
-- # Send to Scratchpad
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
-- # Gaming Workspace
hl.bind(mainMod .. " + G", hl.dsp.focus({ workspace = "name:gaming" }))

-- ## Window Groups

-- # Create / Dissolve Group
hl.bind(mainMod .. " + ALT + G", hl.dsp.group.toggle())
-- # Cycle Group Windows
hl.bind(mainMod .. " + ALT + Tab", hl.dsp.group.next())
-- # Lock / Unlock Group
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.lock())
-- ## Mouse Binds

-- # Drag to Move Window
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- # Drag to Resize Window
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ## Zoom

local function zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	if (zoomvalue + value) > 3.0 then
		hl.config({ cursor = { zoom_factor = 3.0 } })
	elseif (zoomvalue + value) < 1.0 then
		hl.config({ cursor = { zoom_factor = 1.0 } })
	else
		hl.config({ cursor = { zoom_factor = zoomvalue + value } })
	end
end
-- # Zoom Out / In
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + Equal", function() zoomfunction(0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- ## Quickshell Widgets

-- # Toggle App Launcher
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call widgets toggle launcher"))
-- # Toggle Control Center
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call widgets toggle controlCenter"))
-- # Toggle Power Menu
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("qs ipc call widgets toggle powerMenu"))
-- # Toggle Clipboard History
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call widgets toggle clipboard"))
-- # Toggle Wallpaper Selector
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call widgets toggle wallpaper"))
-- # Toggle Screenshot Widget
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("qs ipc call widgets toggle screenshot"))
-- # Toggle Notifications Center
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call widgets toggle notificationsCenter"))
-- # Toggle Settings
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("qs ipc call widgets toggle veyra_settings"))
-- # Toggle Keybinds Manager
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("qs ipc call widgets toggle veyra_keybinds"))
-- # Restart Quickshell
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call veyraSettingsRestart restart"))
-- ## Quickshell Extras (Ctrl+Alt)

-- # Control Center
hl.bind("CTRL + ALT + S", hl.dsp.exec_cmd("qs ipc call widgets toggle controlCenter"))
-- # Power Menu
hl.bind("CTRL + ALT + X", hl.dsp.exec_cmd("qs ipc call widgets toggle powerMenu"))
-- # Wallpaper Selector
hl.bind("CTRL + ALT + W", hl.dsp.exec_cmd("qs ipc call widgets toggle wallpaper"))
-- # Dashboard
hl.bind("CTRL + ALT + D", hl.dsp.exec_cmd("qs ipc call widgets toggle dashboard"))
-- # Music Popup
hl.bind("CTRL + ALT + M", hl.dsp.exec_cmd("qs ipc call widgets toggle music"))
-- # Notifications Center
hl.bind("CTRL + ALT + N", hl.dsp.exec_cmd("qs ipc call widgets toggle notificationsCenter"))
-- # Package Manager
hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd("qs ipc call widgets toggle packagemanager"))
-- # System Monitor
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd("qs ipc call sysmon toggle"))

-- ## Volume

-- # Raise Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptCommand("volume.sh", "up")), { repeating = true, locked = true })
-- # Lower Volume
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptCommand("volume.sh", "down")), { repeating = true, locked = true })
-- # Mute Speaker
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scriptCommand("volume.sh", "mute")), { locked = true })
-- # Mute Microphone
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scriptCommand("volume.sh", "mic-mute")), { locked = true })

-- ## Brightness

-- # Increase Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scriptCommand("brightness.sh", "up")), { repeating = true, locked = true })
-- # Decrease Brightness
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scriptCommand("brightness.sh", "down")), { repeating = true, locked = true })

-- ## Media Player

-- # Play / Pause
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(scriptCommand("media_player.sh", "play-pause")), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scriptCommand("media_player.sh", "play-pause")), { locked = true })
-- # Next Track
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(scriptCommand("media_player.sh", "next")), { locked = true })
-- # Previous Track
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(scriptCommand("media_player.sh", "prev")), { locked = true })
-- # Stop
hl.bind("XF86AudioStop", hl.dsp.exec_cmd(scriptCommand("media_player.sh", "stop")), { locked = true })
-- # Emoji Picker
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(string.format("%q", hyprScripts .. "emoji-toggle.sh")))
