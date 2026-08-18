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
