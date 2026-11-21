-- Hyprland 0.57+ Lua configuration entry point.
-- Keep generated and per-user integration files at the root; core modules live in modules/.
require("modules.animations")
require("modules.autostart")
require("modules.envs")
require("modules.keybinds")

-- Optional user shortcuts created by Veyra Keybinds Manager (generated at the root).
local keybindsOk, keybindsErr = pcall(require, "keybinds_custom")
if not keybindsOk and not tostring(keybindsErr):match("not found") then
    print("[Veyra] keybinds_custom.lua failed to load: " .. tostring(keybindsErr) .. " (ignoring)")
end

require("modules.monitors")
require("userprefs")
require("modules.windowrules")
require("modules.workspaces")
require("modules.effects")
require("modules.alttab")

-- Rice extras (gradient border, dim, gestures, dropdown terminal, app workspaces)
require("modules.rice")
