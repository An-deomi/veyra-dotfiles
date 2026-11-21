-- Load per-user Hyprland preferences without requiring them in the shared rice.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local path = configHome .. "/hypr/userprefs.local.lua"

local ok, values = pcall(dofile, path)
if ok and type(values) == "table" then
    return values
end

return {}
