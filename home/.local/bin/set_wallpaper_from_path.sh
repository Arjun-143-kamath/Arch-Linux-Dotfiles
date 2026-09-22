#!/bin/bash

set -e

CONFIG="$HOME/.config/walltheme/config"

if [ ! -f "$CONFIG" ]; then
    echo "Walltheme configuration not found:"
    exit 1
fi

source "$CONFIG"

WALL="${1:-}"

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    echo "Wallpaper not found:"
    echo "  $WALL"
    exit 1
fi

CURRENT_WALLPAPER_LINK="${CURRENT_WALLPAPER_LINK/#\~/$HOME}"
STATE_FILE="${STATE_FILE/#\~/$HOME}"

mkdir -p "$(dirname "$STATE_FILE")"

# =========================================================
# WALLTHEME STATE
# =========================================================

printf '%s\n' "$WALL" > "$STATE_FILE"

# =========================================================
# DISPLAY
# =========================================================

WALLPAPER_RENDERER="$HOME/.local/bin/walltheme-renderer.sh"

if [ ! -x "$WALLPAPER_RENDERER" ]; then
    echo "Wallpaper renderer not found:"
    echo "  $WALLPAPER_RENDERER"
    exit 1
fi

"$WALLPAPER_RENDERER" "$WALL"

# =========================================================
# THEME GENERATION
# =========================================================

"$HOME/.local/bin/walltheme" "$WALL"

# =========================================================
# PRESENTATION WALLPAPER
# =========================================================

"$HOME/.local/bin/sync_wallpaper_presentation.sh"

# =========================================================
# SDDM
# =========================================================

SDDM_WALLPAPER="/var/lib/sddm-wallpaper/current.png"
SDDM_TEMP="${SDDM_WALLPAPER}.tmp"

rm -f "$SDDM_TEMP"

cp "$(readlink -f "$CURRENT_WALLPAPER_LINK")" "$SDDM_TEMP"

chmod 644 "$SDDM_TEMP"

mv -f "$SDDM_TEMP" "$SDDM_WALLPAPER"

echo "Wallpaper set through Walltheme:"
echo "  $WALL"
