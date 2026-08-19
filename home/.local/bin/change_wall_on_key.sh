#!/bin/bash

set -e

CONFIG="$HOME/.config/walltheme/config"

if [ ! -f "$CONFIG" ]; then
    echo "Walltheme configuration not found:"
    echo "  $CONFIG"
    exit 1
fi

source "$CONFIG"

WALLPAPER_DIR="${WALLPAPER_DIR/#\~/$HOME}"
CURRENT_WALLPAPER_LINK="${CURRENT_WALLPAPER_LINK/#\~/$HOME}"
STATE_FILE="${STATE_FILE/#\~/$HOME}"

mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$CURRENT_WALLPAPER_LINK")"

# =========================================================
# BUILD WALLPAPER LIST
# =========================================================

mapfile -d '' WALLPAPERS < <(
    find "$WALLPAPER_DIR" \
        -maxdepth 1 \
        -type f \
        \( \
            -iname "*.png" \
            -o -iname "*.jpg" \
            -o -iname "*.jpeg" \
            -o -iname "*.webp" \
            -o -iname "*.avif" \
        \) \
        -print0 |
        sort -zV
)

# =========================================================
# MAKE SURE WALLPAPERS EXIST
# =========================================================

if [ "${#WALLPAPERS[@]}" -eq 0 ]; then
    echo "No wallpapers found in:"
    echo "  $WALLPAPER_DIR"
    exit 1
fi

# =========================================================
# READ CURRENT WALLPAPER
# =========================================================

current=""

if [ -f "$STATE_FILE" ]; then
    current="$(cat "$STATE_FILE")"
fi

# =========================================================
# FIND CURRENT WALLPAPER INDEX
# =========================================================

current_index=-1

for i in "${!WALLPAPERS[@]}"; do
    if [ "${WALLPAPERS[$i]}" = "$current" ]; then
        current_index="$i"
        break
    fi
done

# =========================================================
# CALCULATE NEXT WALLPAPER
# =========================================================

if [ "$current_index" -lt 0 ]; then
    next_index=0
else
    next_index=$((current_index + 1))

    if [ "$next_index" -ge "${#WALLPAPERS[@]}" ]; then
        next_index=0
    fi
fi

WALL="${WALLPAPERS[$next_index]}"

# =========================================================
# SAVE STATE
# =========================================================

printf '%s\n' "$WALL" > "$STATE_FILE"

# =========================================================
# KEEP HYPRLOCK SYNCHRONIZED
# =========================================================

ln -sfn "$WALL" "$CURRENT_WALLPAPER_LINK"

# =========================================================
# CHANGE WALLPAPER
# =========================================================

pkill swaybg 2>/dev/null || true

swaybg -i "$WALL" -m fill &

# =========================================================
# APPLY WALLTHEME
# =========================================================

WALLTHEME="$HOME/.local/bin/walltheme"

if [ ! -x "$WALLTHEME" ]; then
    echo "Walltheme executable not found:"
    echo "  $WALLTHEME"
    exit 1
fi

"$WALLTHEME" "$WALL"

# =========================================================
# OUTPUT
# =========================================================

echo
echo "Wallpaper set to:"
echo "  $WALL"
