#!/bin/bash

set -euo pipefail

# ============================================================
# Arch-Linux-Dotfiles Installer
# ============================================================

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false

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

warn() {
    printf '\n\033[1;33mWARNING: %s\033[0m\n' "$1" >&2
}

error() {
    printf '\n\033[1;31mERROR: %s\033[0m\n' "$1" >&2
    exit 1
}

# ============================================================
# ARGUMENTS
# ============================================================

case "${1:-}" in
    "")
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    *)
        error "Unknown option: $1"
        ;;
esac

# ============================================================
# CHECK ENVIRONMENT
# ============================================================

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
fi

if [[ ! -f /etc/arch-release ]]; then
    error "This installer is intended for Arch Linux."
fi

command -v pacman >/dev/null 2>&1 ||
    error "pacman is not available."

command -v git >/dev/null 2>&1 ||
    error "git is not available."

# ============================================================
# PACKAGE HELPERS
# ============================================================

read_packages() {
    local file="$1"

    grep -vE '^[[:space:]]*(#|$)' "$file"
}

# ============================================================
# PACMAN
# ============================================================

install_pacman() {
    info "Installing official Arch packages"

    [[ -f "$PACMAN_FILE" ]] ||
        error "Missing package file: $PACMAN_FILE"

    mapfile -t PACKAGES < <(read_packages "$PACMAN_FILE")

    if ((${#PACKAGES[@]} == 0)); then
        echo "No Pacman packages listed."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: Would install the following Pacman packages:"
        printf '  %s\n' "${PACKAGES[@]}"
        return
    fi

    sudo pacman -S --needed "${PACKAGES[@]}"
}

# ============================================================
# YAY
# ============================================================

ensure_yay() {
    info "Checking yay"

    if command -v yay >/dev/null 2>&1; then
        echo "yay is already installed."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: yay is not installed."
        echo "DRY-RUN: Would install yay from the AUR."
        return
    fi

    echo "yay is not installed."
    echo "Installing yay from the AUR..."

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    trap 'rm -rf "$tmp_dir"' EXIT

    git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"

    (
        cd "$tmp_dir/yay"
        makepkg -si --noconfirm
    )
}

# ============================================================
# AUR
# ============================================================

install_aur() {
    info "Installing AUR packages"

    [[ -f "$AUR_FILE" ]] ||
        error "Missing package file: $AUR_FILE"

    mapfile -t AUR_PACKAGES < <(read_packages "$AUR_FILE")

    if ((${#AUR_PACKAGES[@]} == 0)); then
        echo "No AUR packages listed."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: Would install the following AUR packages:"
        printf '  %s\n' "${AUR_PACKAGES[@]}"
        return
    fi

    command -v yay >/dev/null 2>&1 ||
        error "yay is required for AUR installation."

    yay -S --needed "${AUR_PACKAGES[@]}"
}

# ============================================================
# FLATPAK
# ============================================================

install_flatpak() {
    info "Installing Flatpak applications"

    [[ -f "$FLATPAK_FILE" ]] ||
        error "Missing package file: $FLATPAK_FILE"

    mapfile -t FLATPAKS < <(read_packages "$FLATPAK_FILE")

    if ((${#FLATPAKS[@]} == 0)); then
        echo "No Flatpak applications listed."
        return
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "DRY-RUN: Flatpak is not installed."
            echo "DRY-RUN: Would install:"
            printf '  %s\n' "${FLATPAKS[@]}"
            return
        fi

        warn "Flatpak is not installed; skipping Flatpak applications."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: Would install the following Flatpaks:"
        printf '  %s\n' "${FLATPAKS[@]}"
        return
    fi

    if ! flatpak remotes --columns=name | grep -qx 'flathub'; then
        echo "Adding Flathub..."
        flatpak remote-add --if-not-exists \
            flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    flatpak install -y flathub "${FLATPAKS[@]}"
}

# ============================================================
# NPM
# ============================================================

install_npm() {
    info "Installing global npm packages"

    [[ -f "$NPM_FILE" ]] ||
        error "Missing package file: $NPM_FILE"

    mapfile -t NPM_PACKAGES < <(read_packages "$NPM_FILE")

    if ((${#NPM_PACKAGES[@]} == 0)); then
        echo "No npm packages listed."
        return
    fi

    if ! command -v npm >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "DRY-RUN: npm is not installed."
            echo "DRY-RUN: Would install:"
            printf '  %s\n' "${NPM_PACKAGES[@]}"
            return
        fi

        warn "npm is not installed; skipping npm packages."
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: Would install the following global npm packages:"
        printf '  %s\n' "${NPM_PACKAGES[@]}"
        return
    fi

    npm install --global "${NPM_PACKAGES[@]}"
}

# ============================================================
# DOTFILE DEPLOYMENT
# ============================================================

deploy_dotfiles() {
    info "Deploying dotfiles"

    local source_root="$REPO_DIR/home"
    local backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN MODE: No files will be changed."
    fi

    # Only deploy files tracked by Git.
    # This prevents ignored runtime/state files from being deployed.
    while IFS= read -r -d '' relative; do

        local source="$REPO_DIR/$relative"
        local relative_home="${relative#home/}"
        local target="$HOME/$relative_home"

        if [[ "$DRY_RUN" == true ]]; then
            echo "  [DRY-RUN] Would create parent: $(dirname "$target")"
        else
            mkdir -p "$(dirname "$target")"
        fi

        # Already linked correctly
        if [[ -L "$target" ]] &&
           [[ "$(readlink "$target")" == "$source" ]]; then
            echo "  ✓ $relative_home"
            continue
        fi

        # Existing file/symlink: back it up
        if [[ -e "$target" || -L "$target" ]]; then

            local backup="$backup_root/$relative_home"

            if [[ "$DRY_RUN" == true ]]; then
                echo "  [DRY-RUN] Would backup: $relative_home"
            else
                mkdir -p "$(dirname "$backup")"

                echo "  → Backing up: $relative_home"
                mv "$target" "$backup"
            fi
        fi

        # Create symlink
        if [[ "$DRY_RUN" == true ]]; then
            echo "  [DRY-RUN] Would link: $relative_home"
        else
            ln -s "$source" "$target"
            echo "  + Linked: $relative_home"
        fi

    done < <(
        git -C "$REPO_DIR" ls-files -z -- 'home/*'
    )

    if [[ "$DRY_RUN" == true ]]; then
        echo
        echo "Dry run complete."
        echo "No files were changed."
        return
    fi

    echo
    echo "Dotfiles deployed successfully."

    if [[ -d "$backup_root" ]]; then
        echo
        echo "Existing files were backed up to:"
        echo "  $backup_root"
    fi
}

# ============================================================
# INSTALLATION
# ============================================================

if [[ "$DRY_RUN" == true ]]; then
    info "DRY-RUN MODE"
    echo "No packages or files will be changed."
fi

install_pacman
ensure_yay
install_aur
install_flatpak
install_npm
deploy_dotfiles

# ============================================================
# DONE
# ============================================================

info "Installation complete"

echo
echo "Repository:"
echo "  $REPO_DIR"
echo
echo "Package manifests:"
echo "  pacman  → $PACMAN_FILE"
echo "  AUR     → $AUR_FILE"
echo "  Flatpak → $FLATPAK_FILE"
echo "  npm     → $NPM_FILE"

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "DRY-RUN: No changes were made."
else
    echo
    echo "Dotfiles and packages are ready."
fi
