-- =========================================================
-- MONITOR CONFIGURATION LOADER
-- =========================================================

local hostname_file = io.open("/etc/hostname", "r")

if not hostname_file then
    print("[monitors] Could not read /etc/hostname")
    return
end

local hostname = hostname_file:read("*a")
hostname_file:close()

hostname = hostname:gsub("%s+$", "")

if hostname == "" then
    print("[monitors] Hostname is empty")
    return
end

local machine_config =
    os.getenv("HOME")
    .. "/.config/hypr/machines/"
    .. hostname
    .. "/monitors.lua"

local file = io.open(machine_config, "r")

if not file then
    print("[monitors] No machine-specific monitor configuration found:")
    print("[monitors] " .. machine_config)
    return
end

file:close()

dofile(machine_config)

print("[monitors] Loaded configuration for: " .. hostname)
