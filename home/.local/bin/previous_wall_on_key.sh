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
    -o -iname "*.gif" \
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
# CALCULATE PREVIOUS WALLPAPER
# =========================================================

if [ "$current_index" -lt 0 ]; then
  previous_index=$((${#WALLPAPERS[@]} - 1))
else
  previous_index=$((current_index - 1))

  if [ "$previous_index" -lt 0 ]; then
    previous_index=$((${#WALLPAPERS[@]} - 1))
  fi
fi

WALL="${WALLPAPERS[$previous_index]}"

# =========================================================
# SAVE STATE
# =========================================================

printf '%s\n' "$WALL" >"$STATE_FILE"

# =========================================================
# CHANGE DESKTOP WALLPAPER
# =========================================================

# Apply wallpaper through awww.
awww img "$WALL" \
  --transition-type fade \
  --transition-fps 60

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
# SYNCHRONIZE PRESENTATION WALLPAPER
# =========================================================

"$HOME/.local/bin/sync_wallpaper_presentation.sh"

# =========================================================
# SYNCHRONIZE SDDM
#
# SDDM always receives a static presentation image.
# The actual wallpaper remains in STATE_FILE.
# =========================================================

SDDM_WALLPAPER="/var/lib/sddm-wallpaper/current.png"
SDDM_TEMP="${SDDM_WALLPAPER}.tmp"

rm -f "$SDDM_TEMP"

cp "$(readlink -f "$CURRENT_WALLPAPER_LINK")" "$SDDM_TEMP"

chmod 644 "$SDDM_TEMP"

mv -f "$SDDM_TEMP" "$SDDM_WALLPAPER"

# =========================================================
# OUTPUT
# =========================================================

echo
echo "Wallpaper set to:"
echo "  $WALL"

echo
echo "SDDM wallpaper synchronized."
