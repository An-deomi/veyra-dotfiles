-- Alt-Tab switcher integration.
-- Drives the Quickshell alt-tab instance over its IPC handler, so no
-- separately compiled helper binary is required. Binds are only registered
-- when the optional user service is installed; install.sh --with-alt-tab
-- installs it. hyprland.start also starts the service on login.
local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = home .. "/.config"
end
local altTabDir = configHome .. "/hypr/alt-tab"
local serviceUnit = configHome .. "/systemd/user/fast-alt-tab.service"
local systemServiceUnit = "/usr/lib/systemd/user/fast-alt-tab.service"

local function readable(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

if readable(altTabDir .. "/shell.qml") and (readable(serviceUnit) or readable(systemServiceUnit)) then

    local function action(command)
        return hl.dsp.exec_cmd(string.format("qs ipc -p %q call switcher %s", altTabDir, command))
    end

    hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user start fast-alt-tab.service")
    end)

    hl.bind("ALT + Tab", action("next"))
    hl.bind("ALT + SHIFT + Tab", action("reverse"))
    hl.bind("ALT + Escape", action("cancel"))

    local release = {
        release = true,
        ignore_mods = true,
        transparent = true,
        submap_universal = true,
        non_consuming = true,
    }
    hl.bind("Alt_L", action("commit"), release)
    hl.bind("Alt_R", action("commit"), release)
end
