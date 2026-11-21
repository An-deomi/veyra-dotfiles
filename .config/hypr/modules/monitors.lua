-- Load the single monitor configuration managed by Veyra Settings.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")

if not configHome or configHome == "" then
    configHome = home .. "/.config"
end

local monitorPath = configHome .. "/hypr/monitors.lua"
local ok, err = pcall(dofile, monitorPath)

if not ok then
    print("[Veyra] Could not load " .. monitorPath .. ": " .. tostring(err) .. " (using Hyprland auto-detection)")
end
