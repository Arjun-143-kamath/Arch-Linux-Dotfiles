#!/bin/bash

WALL_DIR="$HOME/Wall"
STATE_FILE="$HOME/.local/state/walltheme/.wall_state"
# Read current wallpaper number
current=$(cat "$STATE_FILE" 2>/dev/null)

# Validate state
if ! [[ "$current" =~ ^[0-9]+$ ]] || [ "$current" -lt 1 ]; then
  echo "Invalid wallpaper state: $current"
  exit 1
fi

WALL="$WALL_DIR/Wall${current}.png"

# Make sure wallpaper exists
if [ ! -f "$WALL" ]; then
  echo "Wallpaper not found: $WALL"
  exit 1
fi

# Update the symlink
ln -sfn "$WALL" "$LINK"

# Start Hyprlock
exec hyprlock
