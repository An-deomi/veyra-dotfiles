-- Read Veyra-managed Hyprland values without modifying userprefs.local.lua.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end

local ok, values = pcall(dofile, configHome .. "/hypr/veyra-settings.lua")
if ok and type(values) == "table" then
    return values
end

return {}
