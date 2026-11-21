-- Veyra window rules merged with the former Noctalia gaming workspace rules.
-- Existing Veyra-specific rules are preserved; Noctalia-only window classes are omitted.

-- Generic floating position and size persistence from the previous setup.
-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Preserve floating window sizes for all applications.
hl.window_rule({
    match = { float = true },
    persistent_size = true,
})

-- Center titled native Wayland floating windows.
-- Leave XWayland popup positioning to the applications.
hl.window_rule({
    match = {
        float = true,
        title = "^(.+)$",
        xwayland = false,
    },
    center = true,
})

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming
local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true, immediate = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    content          = "game",
    decorate         = false,
    fullscreen_state = 2,
    size             = { "monitor_w", "monitor_h" },
    sync_fullscreen  = true,
    immediate        = true,
})
hl.window_rule({
    match = {
        class         = "^(steam_app.*)$",
        initial_title = "^$",
    },
    center           = true,
    float            = true,
    fullscreen       = false,
    fullscreen_state = 0,
    workspace        = gamingWorkspace,
})
hl.window_rule({
    match = { class = "^(dota2)$" },
    workspace = gamingWorkspace,
    content = "game",
    decorate = false,
    fullscreen_state = 2,
    size = { "monitor_w", "monitor_h" },
    sync_fullscreen = true,
    immediate = true,
})


-- Apps
-- Optional output preference; nil leaves Hyprland free to choose the monitor.
local userPrefs = require("local_prefs")
local primaryMonitor = userPrefs.primary_monitor or os.getenv("VEYRA_PRIMARY_MONITOR")
local function addMonitorAwareRule(rule)
    if primaryMonitor and primaryMonitor ~= "" then
        rule.monitor = primaryMonitor
    end
    hl.window_rule(rule)
end
-- Veyra's standalone utility windows should always open centered and floating.
addMonitorAwareRule({
    match = { title = "^Veyra Settings$" },
    float = true,
    center = true,
    -- The app lays its pages out as a single bounded column, so a narrower
    -- window keeps the controls close to their labels instead of leaving
    -- hundreds of pixels of dead space on both sides.
    size = { "monitor_w*0.75", "monitor_h*0.88" },
    opacity = "1.0 override",
    border_size = 1,
})
addMonitorAwareRule({
    match = { title = "^Veyra Package Manager$" },
    float = true,
    center = true,
    size = { "monitor_w*0.76", "monitor_h*0.80" },
    opacity = "1.0 override",
})
addMonitorAwareRule({ match = { class = "^(.*\\.exe)$" }, float = true, center = true, fullscreen_state = 0 })
addMonitorAwareRule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*satty.*)$", title = "^(Satty)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })
hl.window_rule({
    match = {
        class = "^(org\\.kde\\.dolphin)$",
        title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
    },
    float = true,
    size = { "max(monitor_w, monitor_h)*0.50", "min(monitor_w, monitor_h)*0.55" },
    move = {
        "max(20, min(cursor_x - (window_w*0.50), monitor_w - window_w + 20))", -- X axis clamping
        "max(20, min(cursor_y - 50, monitor_h - window_h + 20))" -- Y axis clamping
    },
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|foot|gnome-terminal|xfce[0-9]?-terminal)$"

hl.window_rule({ match = { class = "^(firefox|zen-browser|spotify|discord)$" }, opacity = "1 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" }) -- Override opacity in favor of terminal settings for opacity. If your terminal doesn't support transparency, you can remove this rule.
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Optional rules managed by Veyra Settings. The generated file lives outside
-- the repository and can be removed to return to the built-in rules only.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local customRulesPath = configHome .. "/hypr/windowrules.local.lua"
local customOk, customErr = pcall(dofile, customRulesPath)
if not customOk and customErr and not tostring(customErr):match("No such file") then
    print("[Veyra] Could not load custom window rules: " .. tostring(customErr))
end
