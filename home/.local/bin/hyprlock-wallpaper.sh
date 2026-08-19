#!/bin/bash

set -e

CONFIG="$HOME/.config/walltheme/config"

if [ ! -f "$CONFIG" ]; then
    echo "Walltheme configuration not found:"
    echo "  $CONFIG"
    exit 1
fi

source "$CONFIG"

CURRENT_WALLPAPER_LINK="${CURRENT_WALLPAPER_LINK/#\~/$HOME}"
STATE_FILE="${STATE_FILE/#\~/$HOME}"

mkdir -p "$(dirname "$CURRENT_WALLPAPER_LINK")"

# =========================================================
# READ CURRENT WALLPAPER
# =========================================================

WALL=""

if [ -f "$STATE_FILE" ]; then
    WALL="$(cat "$STATE_FILE")"
fi

# =========================================================
# VALIDATE
# =========================================================

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    echo "Current wallpaper is unavailable."

    # Recover the wallpaper state.
    "$HOME/.local/bin/set_current_wall.sh"

    if [ -f "$STATE_FILE" ]; then
        WALL="$(cat "$STATE_FILE")"
    fi
fi

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    echo "Could not determine current wallpaper."
    exit 1
fi

# =========================================================
# SYNCHRONIZE HYPRLOCK LINK
# =========================================================

ln -sfn "$WALL" "$CURRENT_WALLPAPER_LINK"

# =========================================================
# START HYPRLOCK
# =========================================================

exec hyprlock
