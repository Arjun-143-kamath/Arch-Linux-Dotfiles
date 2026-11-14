-- =========================================================
-- Hyprland 0.55+ Lua configuration
-- Main entry point
-- =========================================================

-- =========================================================
-- CORE CONFIGURATION MODULES
-- =========================================================

require("env")
require("apps")
require("monitors")
require("appearance")
require("config.k4")
require("keybinds")
require("hyprland-gui")
require("hyprglass")

-- =========================================================
-- WALLTHEME
--
-- Loaded LAST so dynamic colors override any static
-- appearance colors.
-- =========================================================

require("walltheme")

-- =========================================================
-- AUTOSTART
-- =========================================================

hl.on("monitor.added", function(monitor)
	if not monitor or not monitor.name or monitor.name == "" then
		return
	end
	hl.exec_cmd("~/.local/bin/wallpaper-monitor-hotplug.sh" .. string.format("%q", monitor.name))
end)

hl.on("hyprland.start", function()
	hl.exec_cmd("hypridle")

	hl.exec_cmd("~/.local/bin/set_current_wall.sh")

	hl.exec_cmd("flatpak run com.github.wwmm.easyeffects --gapplication-service")

	hl.exec_cmd("wl-paste --type text --watch cliphist store")

	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

	hl.exec_cmd("hyprctl dispatch workspace 1")

	hl.exec_cmd("thunar --daemon")

	hl.exec_cmd("hyprsession")

	hl.exec_cmd("hyprctl enable hyprglass")
end)

-- ============================================================
-- k4 user bindings
-- These intentionally live AFTER config.k4 so they override
-- only the conflicting k4 defaults without modifying k4.lua.
-- ============================================================

local k4_root = "/home/arjun/.config/quickshell/k4"
local k4_ipc = "quickshell ipc -p " .. k4_root .. "/shell.qml call k4 "
-- Main k4 interfaces
hl.bind("ALT + SHIFT + K", hl.dsp.exec_cmd(k4_ipc .. "keys"))
--hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(k4_ipc .. "lock"))

-- k4 application launcher
hl.bind("SUPER + Space", hl.dsp.exec_cmd(k4_ipc .. "toggleLauncher"))

-- k4 window switcher
--hl.bind("SUPER + Tab", hl.dsp.global("k4:atalaya"))

-- k4 capture / recording

-- k4 video editor
--local k4_editor = "quickshell ipc -p " .. k4_root .. "/shell.qml call k4.editor "

--hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(k4_editor .. "abrir"))
--hl.bind("SUPER + ALT + E", hl.dsp.exec_cmd(k4_editor .. "retomar"))

-- k4 terminal
--local k4_term = "quickshell ipc -p " .. k4_root .. "/shell.qml call k4.term "

--hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd(k4_term .. "isla"))
--hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd(k4_term .. "mudar"))

-- k4 SSH launcher
--local k4_ssh = "quickshell ipc -p " .. k4_root .. "/shell.qml call k4.ssh "

--hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd(k4_ssh .. "abrir"))

-- k4 AI assistant
--hl.bind("SUPER + G", hl.dsp.exec_cmd(k4_ipc .. "ask"))
--hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd(k4_ipc .. "askScreen"))
--hl.bind("SUPER + ALT + G", hl.dsp.exec_cmd(k4_ipc .. "askRegion"))
--hl.bind("SUPER + CONTROL + G", hl.dsp.exec_cmd(k4_ipc .. "askSelection"))
