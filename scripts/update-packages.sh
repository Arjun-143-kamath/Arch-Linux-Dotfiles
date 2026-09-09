#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Package Manifest Updater
#
# Updates:
#   packages/pacman.txt
#   packages/aur.txt
#   packages/flatpak.txt
#
# This script ONLY updates the manifest files.
# It does not install, remove, or upgrade packages.
# ============================================================

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACMAN_FILE="$REPO_DIR/packages/pacman.txt"
AUR_FILE="$REPO_DIR/packages/aur.txt"
FLATPAK_FILE="$REPO_DIR/packages/flatpak.txt"

TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Requirements
# ------------------------------------------------------------

command -v pacman >/dev/null 2>&1 || {
  echo "ERROR: pacman is not installed."
  exit 1
}

command -v flatpak >/dev/null 2>&1 || {
  echo "ERROR: flatpak is not installed."
  exit 1
}

command -v yay >/dev/null 2>&1 || {
  echo "ERROR: yay is not installed."
  exit 1
}

# ------------------------------------------------------------
# Temporary files
# ------------------------------------------------------------

PACMAN_TMP="$TMP_DIR/pacman.txt"
AUR_TMP="$TMP_DIR/aur.txt"
FLATPAK_TMP="$TMP_DIR/flatpak.txt"

# ------------------------------------------------------------
# Official Arch packages
#
# pacman -Qqe = explicitly installed packages
# pacman -Qn  = packages from official repositories
#
# Combining them gives us explicitly installed official packages.
# ------------------------------------------------------------

echo "Collecting official Arch packages..."

while read -r pkg; do
  if pacman -Qn "$pkg" >/dev/null 2>&1; then
    printf '%s\n' "$pkg"
  fi
done < <(pacman -Qqe | sort) |
  sort -u >"$PACMAN_TMP"

# ------------------------------------------------------------
# AUR packages
#
# pacman considers AUR packages "foreign".
# yay -Si confirms whether the package currently exists in AUR.
#
# Debug split packages are deliberately excluded.
# ------------------------------------------------------------

echo "Collecting AUR packages..."

while read -r pkg; do

  # Ignore debug split packages.
  [[ "$pkg" == *-debug ]] && continue

  if yay -Si "$pkg" >/dev/null 2>&1; then
    printf '%s\n' "$pkg"
  fi

done < <(pacman -Qqm | sort) |
  sort -u >"$AUR_TMP"

# ------------------------------------------------------------
# Flatpak applications
#
# Only applications are tracked.
# Runtime/dependency packages are ignored.
#
# Your current setup uses system Flatpaks, but we combine user
# and system scopes so the manifest remains portable.
# ------------------------------------------------------------

echo "Collecting Flatpak applications..."

{
  flatpak list \
    --user \
    --app \
    --columns=application 2>/dev/null || true

  flatpak list \
    --system \
    --app \
    --columns=application 2>/dev/null || true

} | sed '/^[[:space:]]*$/d' | sort -u >"$FLATPAK_TMP"

# ------------------------------------------------------------
# Show changes
# ------------------------------------------------------------

echo
echo "============================================================"
echo "PACKAGE MANIFEST CHANGES"
echo "============================================================"

show_diff() {
  local label="$1"
  local old="$2"
  local new="$3"

  echo
  echo "--- $label ---"

  if [[ ! -f "$old" ]]; then
    echo "Manifest does not exist; it will be created."
    return
  fi

  if diff -u "$old" "$new"; then
    echo "No changes."
  fi
}

show_diff "pacman.txt" "$PACMAN_FILE" "$PACMAN_TMP"
show_diff "aur.txt" "$AUR_FILE" "$AUR_TMP"
show_diff "flatpak.txt" "$FLATPAK_FILE" "$FLATPAK_TMP"

# ------------------------------------------------------------
# Confirm before writing
# ------------------------------------------------------------

echo
read -rp "Write these changes to the package manifests? [y/N] " answer

case "$answer" in
y | Y | yes | YES)
  ;;
*)
  echo
  echo "Aborted. No files were changed."
  exit 0
  ;;
esac

# ------------------------------------------------------------
# Write manifests
# ------------------------------------------------------------

install -Dm644 "$PACMAN_TMP" "$PACMAN_FILE"
install -Dm644 "$AUR_TMP" "$AUR_FILE"
install -Dm644 "$FLATPAK_TMP" "$FLATPAK_FILE"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo "PACKAGE MANIFESTS UPDATED"
echo "============================================================"

printf 'Official packages : %3d\n' "$(wc -l <"$PACMAN_FILE")"
printf 'AUR packages      : %3d\n' "$(wc -l <"$AUR_FILE")"
printf 'Flatpak apps      : %3d\n' "$(wc -l <"$FLATPAK_FILE")"

echo
echo "Updated:"
echo "  $PACMAN_FILE"
echo "  $AUR_FILE"
echo "  $FLATPAK_FILE"
