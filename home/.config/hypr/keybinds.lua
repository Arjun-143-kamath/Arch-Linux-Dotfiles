-- Keybinds
local apps = require("apps")
local mod = "SUPER"

-- Input
hl.config({
	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			drag_lock = false,
		},
	},
})

-- Gesture
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})
-- Applications
hl.bind(mod .. " + Q", hl.dsp.exec_cmd(apps.terminal))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.filemanager))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(apps.menu))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(apps.screenshot))
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(apps.clipboard))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd(apps.logout))
hl.bind("ALT + SHIFT + right", hl.dsp.exec_cmd(apps.switchwall))
hl.bind("SUPER + W", hl.dsp.exec_cmd(apps.rewaybar))

local apps = require("apps")

-- Floating terminal applications
hl.bind(
	"SUPER + SHIFT + N",
	hl.dsp.exec_cmd("ghostty -e impala", {
		float = true,
		center = true,
	})
)

hl.bind(
	"SUPER + B",
	hl.dsp.exec_cmd("ghostty -e bluetui", {
		float = true,
		center = true,
	})
)

hl.bind(
	"SUPER + A",
	hl.dsp.exec_cmd("ghostty -e btop", {
		float = true,
		center = true,
		size = { 1000, 700 },
	})
)

hl.bind(
	"SUPER + SHIFT + A",
	hl.dsp.exec_cmd("pavucontrol", {
		float = true,
		size = { 1000, 700 },
		center = true,
	})
)

hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(apps.toggle_waybar))

hl.bind("SUPER + Z", hl.dsp.exec_cmd("app.zen_browser.zen"))

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "d" }))

-- Workspaces
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Special workspace
hl.bind(mod .. " + ALT + H", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + ALT + K", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse wheel workspace switching
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse window movement/resizing
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move windows
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Resize submap
hl.bind("ALT + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
	hl.bind("right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
	hl.bind("left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
	hl.bind("up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
	hl.bind("down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })
	hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Volume / brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { repeating = true })

-- Media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
