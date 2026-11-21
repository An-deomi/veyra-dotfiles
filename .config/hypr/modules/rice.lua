-- Rice extras: gradient borders, dimming, extra animations, gestures,
-- dropdown terminal and app -> workspace placement.
-- Loaded last from hyprland.lua. Remove the require line to disable it all.

local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local ok, colors = pcall(dofile, configHome .. "/hypr/colors.local.lua")
if not ok or type(colors) ~= "table" then
    colors = require("colors")
end

local veyraPrefs = require("veyra_prefs")
local glowEnabled = veyraPrefs.shadow_glow_enabled
if glowEnabled == nil then
    glowEnabled = true
end
local glowMode = veyraPrefs.shadow_glow_mode or "accent"
local glowOpacity = tonumber(veyraPrefs.shadow_glow_opacity) or 80
if glowOpacity < 5 then glowOpacity = 5 end
if glowOpacity > 100 then glowOpacity = 100 end

local function withAlpha(colorStr, pct)
    local hex = tostring(colorStr or ""):match("([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]+)")
    if not hex or #hex < 6 then
        return colors.accent_alpha
    end
    local rgb = hex:sub(1, 6)
    local a = math.floor((pct / 100) * 255 + 0.5)
    return string.format("rgba(%s%02x)", rgb, a)
end

local baseGlow = (glowMode == "complementary") and colors.accent_complementary or colors.accent
local activeShadowColor = glowEnabled and withAlpha(baseGlow, glowOpacity) or colors.shadow

local validShaders = {
    vibrance = true,
    ["film-grain"] = true,
    crt = true,
    warm = true,
}
local shaderName = veyraPrefs.screen_shader or "none"
local shaderPath = validShaders[shaderName] and (configHome .. "/hypr/shaders/" .. shaderName .. ".glsl") or ""

-- ## Look -------------------------------------------------------------------
hl.config({
    general = {
        -- Accent -> complementary gradient, follows the wallpaper palette.
        ["col.active_border"] = {
            colors = { colors.accent_alpha, colors.accent_complementary_alpha },
            angle = 45,
        },
    },
    decoration = {
        dim_inactive = true,
        dim_strength = 0.08,
        screen_shader = shaderPath,
        shadow = {
            color = activeShadowColor,
            color_inactive = colors.shadow,
        },
    },
})

-- ## Animations -------------------------------------------------------------
local animCurve = veyraPrefs.anim_curve or "overshot"
local animWinStyle = veyraPrefs.anim_window_style or "popin 80%"
local animWsStyle = veyraPrefs.anim_workspace_style or "slide"
local animSpeedFactor = tonumber(veyraPrefs.anim_speed_factor) or 1.0
if animSpeedFactor < 0.2 then animSpeedFactor = 0.2 end
if animSpeedFactor > 3.0 then animSpeedFactor = 3.0 end

local borderSpin = veyraPrefs.anim_border_spin
if borderSpin == nil then borderSpin = true end
local borderSpeed = tonumber(veyraPrefs.anim_border_speed) or 60
local layersAnim = veyraPrefs.anim_layers
if layersAnim == nil then layersAnim = true end

local function scaledSpeed(base)
    local s = math.floor((base / animSpeedFactor) + 0.5)
    if s < 1 then s = 1 end
    if s > 20 then s = 20 end
    return s
end

hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("spring", { type = "bezier", points = { { 0.22, 1.35 }, { 0.36, 1.0 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = scaledSpeed(4), bezier = animCurve, style = animWinStyle })
hl.animation({ leaf = "windowsOut", enabled = true, speed = scaledSpeed(3), bezier = "ease", style = animWinStyle })
hl.animation({ leaf = "windowsMove", enabled = true, speed = scaledSpeed(4), bezier = animCurve })
hl.animation({ leaf = "fade", enabled = true, speed = scaledSpeed(3), bezier = "ease" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = scaledSpeed(4), bezier = "ease" })
hl.animation({ leaf = "border", enabled = true, speed = scaledSpeed(2), bezier = "ease" })
hl.animation({ leaf = "workspaces", enabled = true, speed = scaledSpeed(5), bezier = animCurve, style = animWsStyle })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = scaledSpeed(5), bezier = animCurve, style = "slidevert" })
hl.animation({ leaf = "borderangle", enabled = borderSpin, speed = borderSpeed, bezier = "linear", style = "loop" })
hl.animation({ leaf = "layers", enabled = layersAnim, speed = scaledSpeed(3), bezier = animCurve, style = "popin 90%" })
hl.animation({ leaf = "fadeLayers", enabled = layersAnim, speed = scaledSpeed(3), bezier = "ease" })

-- ## Touchpad gestures ------------------------------------------------------
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ## Dropdown terminal (SUPER + `) ------------------------------------------
hl.window_rule({
    match = { class = "^(dropterm)$" },
    float = true,
    size = { "monitor_w*0.70", "monitor_h*0.60" },
    move = { "monitor_w*0.15", "monitor_h*0.06" },
    workspace = "special:term",
})
hl.bind("SUPER + grave", function()
    hl.exec_cmd("pgrep -f 'kitty --class dropterm' >/dev/null || kitty --class dropterm")
    hl.dispatch(hl.dsp.workspace.toggle_special("term"))
end)

-- ## App -> workspace placement ---------------------------------------------
hl.window_rule({ match = { class = "^(discord|vesktop|org\\.telegram\\.desktop|telegram-desktop)$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^([Ss]potify)$" }, workspace = "4 silent" })

-- ## Smart workspace gaps (wider framing when only 1 tiled window is open)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 16, gaps_in = 6 })

-- ## Hide sensitive windows from screen sharing / OBS / portals
hl.window_rule({
    match = { class = "^(proton-pass|Proton Pass|org\\.keepassxc\\.KeePassXC|bitwarden|Bitwarden|1Password|org\\.telegram\\.desktop|telegram-desktop)$" },
    no_screen_share = true,
})

-- ## Night Light (hyprsunset) ------------------------------------------------
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("qs ipc call nightLight toggle"))

-- ## Screen Shader Cycle -----------------------------------------------------
hl.bind("SUPER + ALT + H", hl.dsp.exec_cmd("qs ipc call screenShader cycle"))
