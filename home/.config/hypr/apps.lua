-- Application / script variables
-- Lua tables replace the old $variables from hyprlang.

local M = {
    terminal = "ghostty",
    filemanager = "thunar",
    menu = [[rofi -modes "drun,filebrowser,window,ssh" -show drun -show-icons -icon-theme "Papirus"]],
    screenshot = [[grim -g "$(slurp)" - | satty -f -]],
    clipboard = [[cliphist list | rofi -dmenu | cliphist decode | wl-copy]],
    logout = "wlogout",
    rewaybar = "~/.local/bin/killwaybar.sh",
    switchwall = "~/.local/bin/change_wall_on_key.sh",
    network = "ghostty -e impala",
    blue = "ghostty -e bluetui",
    activity = "ghostty -e btop",
    pavu = "pavucontrol",
    browser = "zen-browser",
    tmenu = "ghostty -e tux",
    tclock = "ghostty -e tty-clock -scB",
    toggle_waybar = "~/.local/bin/toggle_Waybar.sh",
}

return M
