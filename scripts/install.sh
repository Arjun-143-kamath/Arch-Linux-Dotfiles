#!/bin/bash

set -euo pipefail

# ============================================================
# Arch-Linux-Dotfiles Installer
# ============================================================

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACMAN_FILE="$REPO_DIR/packages/pacman.txt"
AUR_FILE="$REPO_DIR/packages/aur.txt"
FLATPAK_FILE="$REPO_DIR/packages/flatpak.txt"
NPM_FILE="$REPO_DIR/packages/npm.txt"

# ============================================================
# HELPERS
# ============================================================

info() {
    printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

error() {
    printf '\n\033[1;31mERROR: %s\033[0m\n' "$1" >&2
    exit 1
}

# ============================================================
# CHECK ENVIRONMENT
# ============================================================

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
fi

if [[ ! -f /etc/arch-release ]]; then
    error "This installer is intended for Arch Linux."
fi

command -v pacman >/dev/null 2>&1 \
    || error "pacman is not available."

# ============================================================
# PACMAN
# ============================================================

info "Installing official Arch packages"

if [[ -f "$PACMAN_FILE" ]]; then
    sudo pacman -S --needed \
        $(grep -vE '^[[:space:]]*(#|$)' "$PACMAN_FILE")
else
    error "Missing package file: $PACMAN_FILE"
fi

# ============================================================
# YAY
# ============================================================

info "Checking yay"

if ! command -v yay >/dev/null 2>&1; then
    echo "yay is not installed."
    echo "Installing yay from the AUR..."

    TMP_DIR="$(mktemp -d)"

    trap 'rm -rf "$TMP_DIR"' EXIT

    git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"

    (
        cd "$TMP_DIR/yay"
        makepkg -si --noconfirm
    )
fi

# ============================================================
# AUR
# ============================================================

info "Installing AUR packages"

if [[ -f "$AUR_FILE" ]]; then
    mapfile -t AUR_PACKAGES < <(
        grep -vE '^[[:space:]]*(#|$)' "$AUR_FILE"
    )

    if (( ${#AUR_PACKAGES[@]} > 0 )); then
        yay -S --needed "${AUR_PACKAGES[@]}"
    fi
else
    error "Missing package file: $AUR_FILE"
fi

# ============================================================
# FLATPAK
# ============================================================

info "Installing Flatpak applications"

if command -v flatpak >/dev/null 2>&1; then

    if ! flatpak remotes --columns=name | grep -qx 'flathub'; then
        echo "Adding Flathub..."
        flatpak remote-add --if-not-exists \
            flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    if [[ -f "$FLATPAK_FILE" ]]; then
        mapfile -t FLATPAKS < <(
            grep -vE '^[[:space:]]*(#|$)' "$FLATPAK_FILE"
        )

        if (( ${#FLATPAKS[@]} > 0 )); then
            flatpak install -y flathub "${FLATPAKS[@]}"
        fi
    else
        error "Missing package file: $FLATPAK_FILE"
    fi

else
    echo "Flatpak is not installed; skipping Flatpak applications."
fi

# ============================================================
# NPM
# ============================================================

info "Installing global npm packages"

if command -v npm >/dev/null 2>&1; then

    if [[ -f "$NPM_FILE" ]]; then
        mapfile -t NPM_PACKAGES < <(
            grep -vE '^[[:space:]]*(#|$)' "$NPM_FILE"
        )

        if (( ${#NPM_PACKAGES[@]} > 0 )); then
            npm install --global "${NPM_PACKAGES[@]}"
        fi
    else
        error "Missing package file: $NPM_FILE"
    fi

else
    echo "npm is not installed; skipping npm packages."
fi

# ============================================================
# DONE
# ============================================================

info "Package installation complete"

echo
echo "Repository:"
echo "  $REPO_DIR"
echo
echo "Package manifests:"
echo "  pacman  → $PACMAN_FILE"
echo "  AUR     → $AUR_FILE"
echo "  Flatpak → $FLATPAK_FILE"
echo "  npm     → $NPM_FILE"
echo
echo "Next step will be deploying the dotfiles."
