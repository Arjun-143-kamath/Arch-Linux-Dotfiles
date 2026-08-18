#!/bin/bash

WALL_DIR="$HOME/Wall"
STATE_FILE="$HOME/.local/state/walltheme/.wall_state"
WALLTHEME="$HOME/.local/bin/walltheme"

# =========================================================
# READ CURRENT WALLPAPER NUMBER
# =========================================================

current=$(cat "$STATE_FILE" 2>/dev/null)

# =========================================================
# VALIDATE STATE
# =========================================================

if ! [[ "$current" =~ ^[0-9]+$ ]]; then
  current=1
fi

WALL="$WALL_DIR/Wall${current}.png"

# =========================================================
# MAKE SURE WALLPAPER EXISTS
# =========================================================

if [ ! -f "$WALL" ]; then
  echo "Wallpaper not found: $WALL"
  exit 1
fi

# =========================================================
# Keep Hyprlock synchronized with the active wallpaper
ln -sfn "$WALL" "$HOME/Wall/hyprlock-wallpaper.png"

# SET WALLPAPER
#
# This does NOT modify the state.
# =========================================================

pkill swaybg 2>/dev/null

swaybg -i "$WALL" -m fill &

# =========================================================
# APPLY WALLTHEME
#
# This generates:
#
#   current.json
#   Waybar theme
#   Hyprland theme
#
# and reloads the relevant components.
# =========================================================

if [ -x "$WALLTHEME" ]; then

  "$WALLTHEME" "$WALL"

else

  echo "Walltheme not found:"
  echo "  $WALLTHEME"

fi
