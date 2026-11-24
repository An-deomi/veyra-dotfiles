-- Load the single monitor configuration managed by Veyra Settings.
-- Falls back cleanly to Hyprland auto-detection on fresh clones without monitors.lua.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")

if not configHome or configHome == "" then
    configHome = home .. "/.config"
end

local monitorPath = configHome .. "/hypr/monitors.lua"
local file = io.open(monitorPath, "r")
local exists = file ~= nil
if file then
    file:close()
end

local ok = false
if exists then
    local err
    ok, err = pcall(dofile, monitorPath)
    if not ok then
        print("[Veyra] Could not load " .. monitorPath .. ": " .. tostring(err) .. " (using Hyprland auto-detection)")
    end
end

if not ok then
    hl.monitor({
        output = "",
        mode = "preferred",
        position = "auto",
        scale = "auto",
    })
end
