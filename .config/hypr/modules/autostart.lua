local home = os.getenv("HOME") or ""
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
	configHome = home .. "/.config"
end

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("(sleep 1 && command -v xrdb >/dev/null 2>&1 && [ -f \"$HOME/.Xresources\" ] && xrdb -merge \"$HOME/.Xresources\") &")
	hl.exec_cmd("(sleep 2 && command -v udiskie >/dev/null 2>&1 && udiskie --no-notify) &")
	hl.exec_cmd("command -v awww-daemon >/dev/null 2>&1 && awww-daemon")
	hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && hypridle")
	hl.exec_cmd("command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type text --watch cliphist store")
	hl.exec_cmd("command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type image --watch cliphist store")
	-- uwsm: complete compositor unit startup (no-op outside a uwsm session)
	hl.exec_cmd("command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1 && uwsm finalize")
	-- Starts the shell and notifies loudly if it comes up with no surfaces.
	hl.exec_cmd(string.format("%q", configHome .. "/quickshell/Scripts/system/start_shell.sh"))
	-- polkit prompts are handled by the Quickshell PolkitDialog module.
	-- gnome-keyring is managed by gnome-keyring-daemon.service.
end)
