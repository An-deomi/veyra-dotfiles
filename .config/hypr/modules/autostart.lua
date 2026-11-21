hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("(sleep 2 && udiskie --no-notify) &")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	-- uwsm: complete compositor unit startup (no-op outside a uwsm session)
	hl.exec_cmd("uwsm check is-active >/dev/null 2>&1 && uwsm finalize")
	-- Starts the shell and notifies loudly if it comes up with no surfaces.
	hl.exec_cmd((os.getenv("HOME") or "") .. "/.config/quickshell/Scripts/system/start_shell.sh")
--	hl.exec_cmd("nm-applet --indicator")
	-- polkit prompts are handled by the Quickshell PolkitDialog module.
	-- gnome-keyring is managed by gnome-keyring-daemon.service.
end)