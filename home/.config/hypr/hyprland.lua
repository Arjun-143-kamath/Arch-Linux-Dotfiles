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

hl.on("hyprland.start", function()
	hl.exec_cmd("hypridle")

	hl.exec_cmd("tide-island")

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

-- Tide Island shortcuts: begin (managed by Tide Island Config App).
-- Empty shortcuts are disabled and intentionally omitted.
hl.bind(
	"SUPER + SHIFT + TAB",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call overview toggle")
)
hl.bind(
	"SUPER + SHIFT + right",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide swipeRight")
)
hl.bind(
	"SUPER + SHIFT + left",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide swipeLeft")
)
hl.bind(
	"SUPER + down",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide showClock")
)
hl.bind(
	"SUPER + SHIFT + T",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide showTimer")
)
hl.bind(
	"SUPER + SHIFT + P",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide togglePlayer")
)
hl.bind(
	"SUPER + SHIFT + C",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide toggleControlCenter")
)
hl.bind(
	"SUPER + ALT + P",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide togglePowerMenu")
)
hl.bind(
	"SUPER + N",
	hl.dsp.exec_cmd(
		"/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide toggleNotificationCenter"
	)
)
hl.bind(
	"SUPER + ALT + W",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide toggleWallpaperPicker")
)
hl.bind(
	"SUPER + space",
	hl.dsp.exec_cmd(
		"/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide toggleApplicationLauncher"
	)
)
hl.bind(
	"SUPER + O",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call tide toggleFileShelf")
)
hl.bind(
	"SUPER + SHIFT + F",
	hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call island toggle")
)
-- Tide Island shortcuts: end.
