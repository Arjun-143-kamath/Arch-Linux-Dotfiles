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

THEME_FILE="$HOME/.config/walltheme/current.json"

# =========================================================
# DETERMINE PRESENTATION WALLPAPER
# =========================================================

PRESENTATION=""

if [ -f "$THEME_FILE" ]; then
    PRESENTATION="$(
        python - "$THEME_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r") as file:
    theme = json.load(file)

print(
    theme.get(
        "presentation_wallpaper",
        theme.get("wallpaper", "")
    )
)
PY
    )"
fi

# Fall back to the actual wallpaper state if the theme
# file does not contain presentation information.
if [ -z "$PRESENTATION" ] && [ -f "$STATE_FILE" ]; then
    PRESENTATION="$(cat "$STATE_FILE")"
fi

if [ -z "$PRESENTATION" ] || [ ! -f "$PRESENTATION" ]; then
    echo "Presentation wallpaper is unavailable."
    exit 1
fi

# =========================================================
# UPDATE HYPRLOCK PRESENTATION LINK
# =========================================================

mkdir -p "$(dirname "$CURRENT_WALLPAPER_LINK")"

ln -sfn "$PRESENTATION" "$CURRENT_WALLPAPER_LINK"

echo "Presentation wallpaper:"
echo "  $PRESENTATION"
