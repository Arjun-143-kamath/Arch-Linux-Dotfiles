# Arch Linux Dotfiles

Personal Arch Linux + Hyprland setup focused on modular configuration, dynamic wallpaper theming, and easy deployment.

## Features

- Modular Lua-based Hyprland configuration
- Machine-specific monitor configurations
- Dynamic wallpaper-based theming with Walltheme
- Synchronized themes for Hyprland, Waybar, Ghostty, and Hyprlock
- Wallpaper management using awww and mpvpaper
- Waybar, Ghostty, Rofi, Neovim, Yazi, and other application configurations
- K4 QuickShell integration as a Git submodule
- Package manifests for Pacman, AUR, Flatpak, and npm
- Automated installation and configuration deployment

## Repository Structure

| Directory | Description |
|---|---|
| `home/` | User configurations |
| `machines/` | Machine-specific configurations |
| `packages/` | Package manifests |
| `system/` | System-level configurations |
| `scripts/` | Installation and maintenance scripts |

## Installation

Clone the repository with its submodules:

```bash
git clone --recurse-submodules https://github.com/Arjun-143-kamath/Arch-Linux-Dotfiles.git ~/Repositories/ark-dotfiles
cd ~/Repositories/ark-dotfiles
```

Preview the installation:

```bash
./scripts/install.sh --dry-run
```

Run the installer:

```bash
./scripts/install.sh
```

Review package manifests and system configurations before installing on another machine.

## Updating

Update the repository and submodules:

```bash
git pull --recurse-submodules
git submodule update --init --recursive
```

Refresh package manifests:

```bash
./scripts/update-packages.sh
```

## Notes

- Designed for Arch Linux.
- Existing configurations are backed up before replacement by the installer.
- Generated files, secrets, caches, and runtime data are not tracked.
- Kew library and local state are intentionally excluded.
- Wallpapers are stored separately in `~/Wall`.
