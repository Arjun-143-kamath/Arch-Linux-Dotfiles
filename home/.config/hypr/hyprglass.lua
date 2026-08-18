if not hl.plugin.hyprglass then
	return
end

local hg = hl.plugin.hyprglass

-- Global HyprGlass configuration
hg.config({
	enabled = true,

	default_theme = "dark",
	default_preset = "arjun_glass",

	manage_window_blur = true,

	tint_color = 0x1e282920,

	dark = {
		brightness = 0.82,
		contrast = 0.92,
		saturation = 0.82,
		vibrancy = 0.15,
		adaptive_dim = 0.35,
	},

	layers = {
		enabled = true,
	},
})

-- Waybar
hg.layer("waybar", {
	preset = "subtle",
	mask_threshold = 0.05,
})

-- SwayNC
hg.layer("swaync", {
	preset = "subtle",
	mask_threshold = 0.05,
})

-- Your custom glass preset
hg.preset("arjun_glass", {
	inherits = "glass",

	glass_opacity = 0.88,
	blur_strength = 4,
	blur_iterations = 3,

	refraction_strength = 0.48,
	chromatic_aberration = 0.5,
	fresnel_strength = 0.45,
	specular_strength = 0.5,

	edge_thickness = 0.5,
	lens_distortion = 0.85,

	dark = {
		brightness = 0.82,
		contrast = 0.94,
		saturation = 0.82,
		vibrancy = 0.35,
		adaptive_dim = 0.35,
	},
})

-- Disable HyprGlass on fullscreen windows
hl.window_rule({
	match = {
		fullscreen = true,
	},
	tag = "+hyprglass_disabled",
})

-- Disable HyprGlass on MPV
hl.window_rule({
	match = {
		class = "mpv",
	},
	tag = "+hyprglass_disabled",
})
