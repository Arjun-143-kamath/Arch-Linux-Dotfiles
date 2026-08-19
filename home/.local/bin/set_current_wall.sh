#!/bin/bash

set -e

CONFIG="$HOME/.config/walltheme/config"

if [ ! -f "$CONFIG" ]; then
    echo "Walltheme configuration not found:"
    echo "  $CONFIG"
    exit 1
fi

source "$CONFIG"

# Expand ~ if present.
WALLPAPER_DIR="${WALLPAPER_DIR/#\~/$HOME}"
CURRENT_WALLPAPER_LINK="${CURRENT_WALLPAPER_LINK/#\~/$HOME}"
STATE_FILE="${STATE_FILE/#\~/$HOME}"

mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$CURRENT_WALLPAPER_LINK")"

# =========================================================
# READ CURRENT WALLPAPER
# =========================================================

WALL=""

if [ -f "$STATE_FILE" ]; then
    WALL="$(cat "$STATE_FILE")"
fi

# =========================================================
# VALIDATE CURRENT WALLPAPER
# =========================================================

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then

    echo "Current wallpaper is missing."

    # Pick the first available wallpaper.
    for ext in $WALLPAPER_EXTENSIONS; do
        WALL="$(find "$WALLPAPER_DIR" \
            -maxdepth 1 \
            -type f \
            -iname "*.$ext" \
            -print0 2>/dev/null |
            sort -zV |
            xargs -0 -r -n1 printf '%s\n' |
            head -n1)"

        if [ -n "$WALL" ]; then
            break
        fi
    done
fi

# =========================================================
# MAKE SURE WALLPAPER EXISTS
# =========================================================

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    echo "No wallpapers found in:"
    echo "  $WALLPAPER_DIR"
    exit 1
fi

# =========================================================
# SAVE CURRENT WALLPAPER
# =========================================================

printf '%s\n' "$WALL" > "$STATE_FILE"

# =========================================================
# KEEP HYPRLOCK SYNCHRONIZED
# =========================================================

ln -sfn "$WALL" "$CURRENT_WALLPAPER_LINK"

# =========================================================
# SET WALLPAPER
# =========================================================

pkill swaybg 2>/dev/null || true

swaybg -i "$WALL" -m fill &

# =========================================================
# APPLY WALLTHEME
# =========================================================

WALLTHEME="$HOME/.local/bin/walltheme"

if [ -x "$WALLTHEME" ]; then
    "$WALLTHEME" "$WALL"
else
    echo "Walltheme executable not found:"
    echo "  $WALLTHEME"
    exit 1
fi

echo
echo "Current wallpaper:"
echo "  $WALL"
