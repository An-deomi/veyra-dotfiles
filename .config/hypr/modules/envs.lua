local userPrefs = require("local_prefs")
local veyraPrefs = require("veyra_prefs")

local home = os.getenv("HOME") or ""
local dataHome = os.getenv("XDG_DATA_HOME")
if not dataHome or dataHome == "" then
    dataHome = home .. "/.local/share"
end

local function cursorThemeInstalled(name)
    if not name or name == "" then
        return false
    end
    local candidates = {
        home .. "/.icons/" .. name .. "/cursors",
        home .. "/.icons/" .. name .. "/index.theme",
        dataHome .. "/icons/" .. name .. "/cursors",
        dataHome .. "/icons/" .. name .. "/index.theme",
        "/usr/share/icons/" .. name .. "/cursors",
        "/usr/share/icons/" .. name .. "/index.theme",
    }
    for _, path in ipairs(candidates) do
        local f = io.open(path, "r")
        if f then
            f:close()
            return true
        end
    end
    return false
end

local preferredCursor = veyraPrefs.cursor_theme or userPrefs.cursor_theme or os.getenv("VEYRA_CURSOR_THEME")
local cursorTheme = preferredCursor
if not cursorTheme or cursorTheme == "" or not cursorThemeInstalled(cursorTheme) then
    if cursorThemeInstalled("Bibata-Modern-Ice") then
        cursorTheme = "Bibata-Modern-Ice"
    elseif cursorThemeInstalled("Bibata-Modern-Classic") then
        cursorTheme = "Bibata-Modern-Classic"
    else
        cursorTheme = "Adwaita"
    end
end

local cursorSize = tonumber(veyraPrefs.cursor_size or userPrefs.cursor_size or os.getenv("VEYRA_CURSOR_SIZE")) or 24

hl.env("XCURSOR_SIZE", tostring(cursorSize))
hl.env("HYPRCURSOR_SIZE", tostring(cursorSize))
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_THEME", cursorTheme)

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
