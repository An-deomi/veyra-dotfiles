local userPrefs = require("local_prefs")
local veyraPrefs = require("veyra_prefs")

local cursorTheme = veyraPrefs.cursor_theme or userPrefs.cursor_theme or os.getenv("VEYRA_CURSOR_THEME") or "Bibata-Modern-Classic"
local cursorSize = veyraPrefs.cursor_size or userPrefs.cursor_size or tonumber(os.getenv("VEYRA_CURSOR_SIZE")) or 24

hl.env("XCURSOR_SIZE", tostring(cursorSize))
hl.env("HYPRCURSOR_SIZE", tostring(cursorSize))
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_THEME", cursorTheme)

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
