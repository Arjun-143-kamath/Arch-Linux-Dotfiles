#!/bin/bash

set -euo pipefail

# ============================================================
# Arch-Linux-Dotfiles Installer
# ============================================================

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=false

case "${1:-}" in
"")
  ;;
--dry-run)
  DRY_RUN=true
  ;;
*)
  echo "ERROR: Unknown option: $1" >&2
  echo "Usage: $0 [--dry-run]" >&2
  exit 1
  ;;
esac

PACMAN_FILE="$REPO_DIR/packages/pacman.txt"
AUR_FILE="$REPO_DIR/packages/aur.txt"
FLATPAK_FILE="$REPO_DIR/packages/flatpak.txt"
NPM_FILE="$REPO_DIR/packages/npm.txt"

SYSTEM_ROOT="$REPO_DIR/system"

# ============================================================
# HELPERS
# ============================================================

info() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

warn() {
  printf '\033[1;33mWARNING: %s\033[0m\n' "$1"
}

error() {
  printf '\n\033[1;31mERROR: %s\033[0m\n' "$1" >&2
  exit 1
}

# ============================================================
# DOTFILE DEPLOYMENT
# ============================================================

deploy_dotfiles() {
  info "Deploying dotfiles"

  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY-RUN MODE: No files will be changed."
  fi

  local source_root="$REPO_DIR/home"
  local backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

  while IFS= read -r -d '' source; do
    local relative="${source#"$source_root"/}"
    local target="$HOME/$relative"

    # ----------------------------------------------------
    # Create target parent directory
    # ----------------------------------------------------

    if [[ "$DRY_RUN" == true ]]; then
      echo "  [DRY-RUN] Would create parent: $(dirname "$target")"
    else
      mkdir -p "$(dirname "$target")"
    fi

    # ----------------------------------------------------
    # Already linked correctly
    # ----------------------------------------------------

    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
      echo "  ✓ $relative"
      continue
    fi

    # ----------------------------------------------------
    # Existing file/symlink: back it up
    # ----------------------------------------------------

    if [[ -e "$target" || -L "$target" ]]; then
      local backup="$backup_root/$relative"

      if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] Would backup: $relative"
      else
        mkdir -p "$(dirname "$backup")"

        echo "  → Backing up: $relative"
        mv "$target" "$backup"
      fi
    fi

    # ----------------------------------------------------
    # Create symlink
    # ----------------------------------------------------

    if [[ "$DRY_RUN" == true ]]; then
      echo "  [DRY-RUN] Would link: $relative"
    else
      ln -s "$source" "$target"
      echo "  + Linked: $relative"
    fi

  done < <(
    find "$source_root" -type f -print0
  )

  echo
  echo "Dotfiles deployed successfully."

  if [[ "$DRY_RUN" == false && -d "$backup_root" ]]; then
    echo
    echo "Existing files were backed up to:"
    echo "  $backup_root"
  fi
}

# ============================================================
# SYSTEM FILE DEPLOYMENT
# ============================================================

deploy_system_file() {
  local source="$1"
  local target="$2"
  local mode="$3"
  local backup_root="$4"

  # --------------------------------------------------------
  # Dry run
  # --------------------------------------------------------

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY-RUN] Would install:"
    echo "             $source"
    echo "          →  $target"
    return
  fi

  # --------------------------------------------------------
  # Create target parent directory
  # --------------------------------------------------------

  sudo mkdir -p "$(dirname "$target")"

  # --------------------------------------------------------
  # Existing file: compare and back up if different
  # --------------------------------------------------------

  if [[ -e "$target" || -L "$target" ]]; then

    if cmp -s "$source" "$target" 2>/dev/null; then
      echo "  ✓ $target"
      return
    fi

    local relative="${target#/}"
    local backup="$backup_root/$relative"

    sudo mkdir -p "$(dirname "$backup")"

    echo "  → Backing up: $target"
    sudo cp -a "$target" "$backup"
  fi

  # --------------------------------------------------------
  # Install system file
  # --------------------------------------------------------

  echo "  + Installing: $target"

  sudo install \
    -m "$mode" \
    "$source" \
    "$target"
}

# ============================================================
# SYSTEM CONFIGURATION
# ============================================================

deploy_system() {
  info "Deploying system configuration"

  if [[ ! -d "$SYSTEM_ROOT" ]]; then
    warn "No system configuration directory found."
    return
  fi

  local backup_root="/var/backups/arch-linux-dotfiles/$(date +%Y%m%d-%H%M%S)"

  # --------------------------------------------------------
  # greetd
  # --------------------------------------------------------

  if [[ -f "$SYSTEM_ROOT/greetd/config.toml" ]]; then
    deploy_system_file \
      "$SYSTEM_ROOT/greetd/config.toml" \
      "/etc/greetd/config.toml" \
      "644" \
      "$backup_root"
  fi

  if [[ -f "$SYSTEM_ROOT/greetd/regreet.toml" ]]; then
    deploy_system_file \
      "$SYSTEM_ROOT/greetd/regreet.toml" \
      "/etc/greetd/regreet.toml" \
      "644" \
      "$backup_root"
  fi

  # --------------------------------------------------------
  # SDDM
  # --------------------------------------------------------

  if [[ -f "$SYSTEM_ROOT/sddm/theme.conf" ]]; then
    deploy_system_file \
      "$SYSTEM_ROOT/sddm/theme.conf" \
      "/etc/sddm.conf.d/theme.conf" \
      "644" \
      "$backup_root"
  fi

  if [[ -f "$SYSTEM_ROOT/sddm/wallpaper.conf" ]]; then
    deploy_system_file \
      "$SYSTEM_ROOT/sddm/wallpaper.conf" \
      "/etc/sddm.conf.d/wallpaper.conf" \
      "644" \
      "$backup_root"
  fi

  # --------------------------------------------------------
  # System scripts
  # --------------------------------------------------------

  if [[ -f "$SYSTEM_ROOT/usr/local/bin/sddm-wallpaper" ]]; then
    deploy_system_file \
      "$SYSTEM_ROOT/usr/local/bin/sddm-wallpaper" \
      "/usr/local/bin/sddm-wallpaper" \
      "755" \
      "$backup_root"
  fi

  echo
  echo "System configuration deployed."

  if [[ "$DRY_RUN" == false && -d "$backup_root" ]]; then
    echo
    echo "Existing system files were backed up to:"
    echo "  $backup_root"
  fi
}

# ============================================================
# DISPLAY MANAGER STATUS
# ============================================================

check_display_manager() {
  info "Display manager status"

  local sddm_enabled=false
  local greetd_enabled=false

  if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
    sddm_enabled=true
  fi

  if systemctl is-enabled --quiet greetd.service 2>/dev/null; then
    greetd_enabled=true
  fi

  if [[ "$sddm_enabled" == true && "$greetd_enabled" == true ]]; then
    warn "Both SDDM and greetd are enabled."
    warn "Only one display manager should normally be enabled."

  elif [[ "$sddm_enabled" == true ]]; then
    echo "  ✓ SDDM is enabled."

  elif [[ "$greetd_enabled" == true ]]; then
    echo "  ✓ greetd is enabled."

  else
    warn "No supported display manager is enabled."
  fi
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

command -v pacman >/dev/null 2>&1 ||
  error "pacman is not available."

command -v sudo >/dev/null 2>&1 ||
  error "sudo is required."

# ============================================================
# DRY RUN HEADER
# ============================================================

if [[ "$DRY_RUN" == true ]]; then
  info "DRY-RUN MODE"
  echo "No packages or files will be changed."
fi

# ============================================================
# PACMAN
# ============================================================

info "Installing official Arch packages"

if [[ -f "$PACMAN_FILE" ]]; then

  mapfile -t PACMAN_PACKAGES < <(
    grep -vE '^[[:space:]]*(#|$)' "$PACMAN_FILE"
  )

  if ((${#PACMAN_PACKAGES[@]} > 0)); then

    if [[ "$DRY_RUN" == true ]]; then
      echo "DRY-RUN: Would install the following Pacman packages:"
      printf '  %s\n' "${PACMAN_PACKAGES[@]}"
    else
      sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"
    fi

  fi

else
  error "Missing package file: $PACMAN_FILE"
fi

# ============================================================
# YAY
# ============================================================

info "Checking yay"

if ! command -v yay >/dev/null 2>&1; then

  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY-RUN: yay is not installed."
    echo "DRY-RUN: Would install yay from the AUR."

  else
    echo "yay is not installed."
    echo "Installing yay from the AUR..."

    TMP_DIR="$(mktemp -d)"

    trap 'rm -rf "$TMP_DIR"' EXIT

    git clone \
      https://aur.archlinux.org/yay.git \
      "$TMP_DIR/yay"

    (
      cd "$TMP_DIR/yay"
      makepkg -si --noconfirm
    )
  fi

else
  echo "yay is already installed."
fi

# ============================================================
# AUR
# ============================================================

info "Installing AUR packages"

if [[ -f "$AUR_FILE" ]]; then

  mapfile -t AUR_PACKAGES < <(
    grep -vE '^[[:space:]]*(#|$)' "$AUR_FILE"
  )

  if ((${#AUR_PACKAGES[@]} > 0)); then

    if [[ "$DRY_RUN" == true ]]; then
      echo "DRY-RUN: Would install the following AUR packages:"
      printf '  %s\n' "${AUR_PACKAGES[@]}"

    else
      yay -S --needed "${AUR_PACKAGES[@]}"
    fi

  fi

else
  error "Missing package file: $AUR_FILE"
fi

# ============================================================
# FLATPAK
# ============================================================

info "Installing Flatpak applications"

if command -v flatpak >/dev/null 2>&1; then

  if [[ "$DRY_RUN" == true ]]; then

    if [[ -f "$FLATPAK_FILE" ]]; then
      mapfile -t FLATPAKS < <(
        grep -vE '^[[:space:]]*(#|$)' "$FLATPAK_FILE"
      )

      if ((${#FLATPAKS[@]} > 0)); then
        echo "DRY-RUN: Would install the following Flatpaks:"
        printf '  %s\n' "${FLATPAKS[@]}"
      fi
    else
      error "Missing package file: $FLATPAK_FILE"
    fi

  else

    if ! flatpak remotes --columns=name | grep -qx 'flathub'; then
      echo "Adding Flathub..."

      flatpak remote-add \
        --if-not-exists \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    if [[ -f "$FLATPAK_FILE" ]]; then

      mapfile -t FLATPAKS < <(
        grep -vE '^[[:space:]]*(#|$)' "$FLATPAK_FILE"
      )

      if ((${#FLATPAKS[@]} > 0)); then
        flatpak install -y flathub "${FLATPAKS[@]}"
      fi

    else
      error "Missing package file: $FLATPAK_FILE"
    fi

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

    if ((${#NPM_PACKAGES[@]} > 0)); then

      if [[ "$DRY_RUN" == true ]]; then
        echo "DRY-RUN: Would install the following npm packages:"
        printf '  %s\n' "${NPM_PACKAGES[@]}"

      else
        npm install --global "${NPM_PACKAGES[@]}"
      fi

    else
      echo "No npm packages listed."
    fi

  else
    error "Missing package file: $NPM_FILE"
  fi

else
  echo "npm is not installed; skipping npm packages."
fi

# ============================================================
# DOTFILES
# ============================================================

deploy_dotfiles

# ============================================================
# SYSTEM CONFIGURATION
# ============================================================

deploy_system

# ============================================================
# DISPLAY MANAGER STATUS
# ============================================================

check_display_manager

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
