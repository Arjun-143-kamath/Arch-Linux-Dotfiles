#!/bin/bash

WALL_DIR="$HOME/Wall"
STATE_FILE="$HOME/.local/state/walltheme/.wall_state"
WALLTHEME="$HOME/.local/bin/walltheme"

# =========================================================
# COUNT WALLPAPERS
# =========================================================

MAX_WALL=$(find "$WALL_DIR" \
  -maxdepth 1 \
  -type f \
  -name "Wall*.png" |
  wc -l)

# =========================================================
# MAKE SURE WALLPAPERS EXIST
# =========================================================

if [ "$MAX_WALL" -eq 0 ]; then
  echo "No wallpapers found in:"
  echo "  $WALL_DIR"
  exit 1
fi

# =========================================================
# INITIALIZE STATE
# =========================================================

if [ ! -f "$STATE_FILE" ]; then
  echo 0 >"$STATE_FILE"
fi

current=$(cat "$STATE_FILE")

# =========================================================
# VALIDATE STATE
# =========================================================

if ! [[ "$current" =~ ^[0-9]+$ ]]; then
  current=0
fi

# =========================================================
# CALCULATE NEXT WALLPAPER
# =========================================================

next=$((current + 1))

if [ "$next" -gt "$MAX_WALL" ]; then
  next=1
fi

# =========================================================
# SAVE STATE
# =========================================================

echo "$next" >"$STATE_FILE"

# =========================================================
# SELECT WALLPAPER
# =========================================================

WALL="$WALL_DIR/Wall${next}.png"

if [ ! -f "$WALL" ]; then
  echo "Wallpaper not found:"
  echo "  $WALL"

  exit 1
fi

# =========================================================
# Keep Hyprlock synchronized with the active wallpaper
ln -sfn "$WALL" "$HOME/Wall/hyprlock-wallpaper.png"

# CHANGE WALLPAPER
# =========================================================

pkill swaybg 2>/dev/null

swaybg -i "$WALL" -m fill &

# =========================================================
# APPLY WALLTHEME
# =========================================================

if [ -x "$WALLTHEME" ]; then

  "$WALLTHEME" "$WALL"

else

  echo "Walltheme not found:"
  echo "  $WALLTHEME"

  exit 1

fi

# =========================================================
# OUTPUT
# =========================================================

echo
echo "Wallpaper set to:"
echo "  $WALL"
