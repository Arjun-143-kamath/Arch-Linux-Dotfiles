-- =========================================================
-- WALLTHEME — Hyprland integration
--
-- Reads:
-- ~/.config/walltheme/current.json
--
-- Applies the generated palette directly through
-- Hyprland's native Lua configuration API.
-- =========================================================

local THEME_FILE = os.getenv("HOME") .. "/.config/walltheme/current.json"

-- =========================================================
-- FILE READER
-- =========================================================

local function read_file(path)
	local file = io.open(path, "r")

	if not file then
		return nil
	end

	local contents = file:read("*a")

	file:close()

	return contents
end

-- =========================================================
-- JSON COLOR READER
--
-- We only need simple string values from current.json.
-- Using a small parser here avoids adding a Lua JSON
-- dependency just for the theme system.
-- =========================================================

local function get_color(json, key)
	local pattern = '"' .. key .. '"%s*:%s*"([^"]+)"'

	return string.match(json, pattern)
end

-- =========================================================
-- LOAD THEME
-- =========================================================

local json = read_file(THEME_FILE)

if not json then
	print("[walltheme] current.json not found: " .. THEME_FILE)

	return
end

local background = get_color(json, "background")

local surface = get_color(json, "surface")

local surface_alt = get_color(json, "surface_alt")

local foreground = get_color(json, "foreground")

local muted = get_color(json, "muted")

local accent = get_color(json, "accent")

local accent_hover = get_color(json, "accent_hover")

local accent_active = get_color(json, "accent_active")

local accent_surface = get_color(json, "accent_surface")

local accent_secondary = get_color(json, "accent_secondary")

local accent_tertiary = get_color(json, "accent_tertiary")

local border = get_color(json, "border")

local selection = get_color(json, "selection")

local warning = get_color(json, "warning")

local error = get_color(json, "error")

local success = get_color(json, "success")

-- =========================================================
-- VALIDATION
-- =========================================================

if not accent_surface then
	print("[walltheme] Missing accent_surface")

	return
end

if not accent then
	print("[walltheme] Missing accent")

	return
end

if not border then
	print("[walltheme] Missing border")

	return
end

-- =========================================================
-- HYPRLAND THEME
-- =========================================================

hl.config({

	general = {

		-- Keep your existing border size.
		-- This only changes colors.
		["col.active_border"] = accent_surface,

		["col.inactive_border"] = border,

		["col.nogroup_border"] = border,

		["col.nogroup_border_active"] = accent_surface,
	},

	-- =====================================================
	-- GROUP COLORS
	-- =====================================================

	group = {

		["col.border_active"] = accent_surface,

		["col.border_inactive"] = border,

		["col.border_locked_active"] = accent_secondary,

		["col.border_locked_inactive"] = border,
	},

	-- =====================================================
	-- GROUPBAR
	-- =====================================================

	group = {

		["col.border_active"] = accent_surface,

		["col.border_inactive"] = border,

		["col.border_locked_active"] = accent_secondary,

		["col.border_locked_inactive"] = border,

		groupbar = {

			["text_color"] = foreground,

			["text_color_inactive"] = muted,

			["col.active"] = accent_surface,

			["col.inactive"] = surface,
		},
	},

	-- =====================================================
	-- MISC
	-- =====================================================

	misc = {

		["background_color"] = background,

		["col.splash"] = foreground,
	},
})

-- =========================================================
-- WALLTHEME STATUS
-- =========================================================

print("[walltheme] Hyprland theme loaded")

print("[walltheme] active border: " .. accent_surface)

print("[walltheme] inactive border: " .. border)

print("[walltheme] accent: " .. accent)
