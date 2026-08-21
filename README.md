# ark-dotfiles

> A modular Arch Linux + Hyprland desktop that adapts its appearance to the wallpaper and its configuration to the hardware.

My personal Arch Linux + Hyprland dotfiles, built around reproducibility, modular configuration, dynamic theming, and machine-specific hardware configuration.

## Highlights

- Arch Linux + Hyprland Wayland desktop
- Modular Lua-based Hyprland configuration
- Machine-aware monitor configuration
- Dynamic wallpaper-driven theming
- Automatic theme generation for Hyprland, Waybar, Ghostty, and Hyprlock
- Synchronized wallpaper state across the desktop, lock screen, and SDDM
- swaybg wallpaper management
- Ghostty terminal with live theme reloads
- Waybar with generated dynamic colors
- Neovim / LazyVim
- Rofi, Yazi, Thunar, btop, Cava, SwayNC, and EasyEffects
- Separate pacman, AUR, Flatpak, and npm package manifests
- Automated installation through `scripts/install.sh`
- User and system configuration kept separate
- Runtime state and generated files kept out of Git

---

## Architecture

```text
                    ark-dotfiles
                         │
          ┌──────────────┼──────────────┐
          │              │              │
        home/         machines/       system/
          │              │              │
     User config     Hardware config   System config
          │              │              │
          └──────────────┼──────────────┘
                         │
                  scripts/install.sh
                         │
                         ▼
                 Reproducible system
```

### Repository structure

```text
ark-dotfiles/
├── home/
│   ├── .aliases
│   ├── .bashrc
│   ├── .bash_profile
│   ├── .profile
│   ├── .gitconfig
│   ├── .config/
│   │   ├── hypr/
│   │   ├── waybar/
│   │   ├── ghostty/
│   │   ├── walltheme/
│   │   ├── nvim/
│   │   ├── rofi/
│   │   ├── yazi/
│   │   ├── btop/
│   │   ├── cava/
│   │   ├── kew/
│   │   └── ...
│   └── .local/bin/
│
├── machines/
│   └── ark/
│       └── monitors.lua
├── packages/
│   ├── pacman.txt
│   ├── aur.txt
│   ├── flatpak.txt
│   └── npm.txt
├── system/
│   ├── greetd/
│   ├── sddm/
│   └── usr/local/bin/
├── scripts/
│   └── install.sh
└── README.md
```

---

# Hyprland

Hyprland is the core compositor and window manager.

The configuration is split into Lua modules rather than keeping everything in one file:

```text
~/.config/hypr/
├── hyprland.lua
├── env.lua
├── apps.lua
├── monitors.lua
├── appearance.lua
├── keybinds.lua
├── hyprland-gui.lua
├── hyprglass.lua
├── walltheme.lua
├── hypridle.conf
└── hyprlock.conf
```

The main entry point imports these modules and handles session startup.

Autostart includes Hypridle, dynamic wallpaper/theme initialization, EasyEffects, cliphist, the Polkit agent, Thunar, Hyprsession, and Hyprglass.

---

# Machine-Specific Configuration

Hardware-specific configuration is deliberately separated from the generic Hyprland configuration.

The generic monitor loader reads the hostname and loads:

```text
~/.config/hypr/machines/<hostname>/monitors.lua
```

For example:

```text
machines/
└── ark/
    └── monitors.lua
```

This keeps monitor names, resolution, position, scale, and workspace assignments out of the portable Hyprland configuration.

Adding another machine only requires another directory:

```text
machines/
├── ark/
│   └── monitors.lua
├── laptop/
│   └── monitors.lua
└── desktop/
    └── monitors.lua
```

---

# Dynamic Wallpaper Theming

The defining feature of this setup is its wallpaper-driven theme system.

A wallpaper is analyzed and converted into a palette which is propagated throughout the desktop.

```text
                         Wallpaper
                             │
                             ▼
                       walltheme.py
                             │
                             ▼
                        current.json
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
       Hyprland           Waybar            Ghostty
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                         Hyprlock
```

The theme generator produces:

- Hyprland colors
- Waybar CSS
- Ghostty configuration
- Hyprlock configuration

Use:

```bash
walltheme <wallpaper>
```

For example:

```bash
walltheme ~/Wall/Wall1.png
```

Generated runtime files live under:

```text
~/.config/walltheme/current.json
~/.config/walltheme/generated/
```

These are intentionally not tracked by Git.

---

# Wallpaper State

Wallpaper state is stored separately from the dotfiles:

```text
~/.local/state/walltheme/current_wallpaper
```

The state file contains the absolute path of the active wallpaper.

A stable symlink provides a single target for components that need the current image:

```text
~/.config/walltheme/current-wallpaper
```

This means Hyprlock does not need a hard-coded wallpaper path.

```text
current_wallpaper
       │
       ▼
current-wallpaper
       │
       ├──► Hyprlock
       └──► Desktop wallpaper/theme system
```

---

# Changing Wallpapers

Wallpaper switching is handled by:

```bash
~/.local/bin/change_wall_on_key.sh
```

It:

1. Finds available wallpapers
2. Determines the next wallpaper
3. Updates persistent wallpaper state
4. Updates the stable wallpaper symlink
5. Restarts `swaybg`
6. Runs `walltheme`
7. Regenerates the desktop theme
8. Reloads the relevant components

Supported image formats include PNG, JPEG, WebP, and AVIF.

---

# Hyprlock Synchronization

Hyprlock uses:

```text
~/.config/walltheme/current-wallpaper
```

When the wallpaper changes, the symlink changes with it.

`hyprlock-wallpaper.sh` verifies the state and synchronizes the link before launching Hyprlock, preventing the lock screen from becoming stuck on an older wallpaper.

---

# SDDM Synchronization

The SDDM wallpaper script is:

```text
system/usr/local/bin/sddm-wallpaper
```

It points the Pixie SDDM theme at the current wallpaper.

The intended flow is:

```text
Current wallpaper
       │
       ├──► Hyprland / swaybg
       ├──► Waybar theme
       ├──► Ghostty theme
       ├──► Hyprlock
       └──► SDDM
```

This keeps the visual identity consistent across login, desktop, and lock screen.

---

# Waybar

Waybar is configured through:

```text
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
```

Configured components include workspaces, window title, media controls, CPU, memory, battery, network, Bluetooth, audio, notifications, clock, and power controls.

---

# Ghostty

Ghostty is the primary terminal emulator.

Static configuration:

```text
~/.config/ghostty/config
```

Generated theme:

```text
~/.config/walltheme/generated/ghostty.conf
```

Running Ghostty instances receive a reload signal when the wallpaper changes, allowing the terminal theme to update without manually restarting terminals.

---

# Neovim

The editor configuration is based on LazyVim:

```text
~/.config/nvim/
```

Important files include:

```text
init.lua
lazy-lock.json
lazyvim.json
lua/config/
lua/plugins/
```

`lazy-lock.json` is tracked so plugin versions can be reproduced.

---

# Package Management

Packages are separated by installation source:

```text
packages/
├── pacman.txt
├── aur.txt
├── flatpak.txt
└── npm.txt
```

The installer handles these automatically.

---

# Installation

## 1. Clone

```bash
git clone <YOUR-REPOSITORY-URL> ~/ark-dotfiles
cd ~/ark-dotfiles
```

## 2. Review

This is a personal configuration. Review package lists and system configuration before using it on another machine.

## 3. Run the installer

```bash
./scripts/install.sh
```

For a safe preview:

```bash
./scripts/install.sh --dry-run
```

The installer can:

- Install official Arch packages
- Install AUR packages through `yay`
- Install Flatpak applications
- Install global npm packages
- Deploy user dotfiles
- Deploy machine-specific configuration
- Install system-level configuration
- Configure display-manager files
- Back up existing files before replacement

---

# Wallpaper Setup

Create the wallpaper directory:

```bash
mkdir -p ~/Wall
```

Add wallpapers:

```text
~/Wall/
├── wallpaper-01.png
├── wallpaper-02.jpg
├── wallpaper-03.webp
└── ...
```

Then initialize the theme:

```bash
walltheme ~/Wall/wallpaper-01.png
```

Wallpaper state is created automatically by the wallpaper scripts.

---

# Updating

The repository includes:

```bash
~/.local/bin/update.sh
```

The shell alias:

```bash
update
```

updates the configured package sources.

---

# Git Hygiene

This repository intentionally avoids tracking runtime and sensitive data.

Do not commit:

- API keys
- Passwords
- Tokens
- Credentials
- `.env` files
- Authentication files
- Browser state
- Application databases
- Generated theme files
- Wallpaper state
- Other machine-specific runtime state

Before committing:

```bash
git diff --check
git status
```

For a quick credential-name check:

```bash
git diff --cached --name-only | grep -Ei '(\.env|secret|token|password|credential|auth\.json|\.pem|\.key)'
```

---

# Design Philosophy

The goal is not to copy an entire home directory into Git.

Instead, the repository tracks the parts of the environment that are meaningful and reproducible:

```text
Tracked
├── Configuration
├── Scripts
├── Themes
├── Package manifests
├── System configuration
├── Machine-specific configuration
└── Editor configuration

Not tracked
├── Secrets
├── Generated files
├── Caches
├── Application databases
├── Wallpaper state
└── Runtime state
```

The result is a modular desktop environment that can be rebuilt without carrying unnecessary machine state with it.

---

# Current Stack

| Category | Software |
|---|---|
| Distribution | Arch Linux |
| Compositor | Hyprland |
| Display Manager | SDDM |
| Greeter | ReGreet / greetd configuration |
| Bar | Waybar |
| Terminal | Ghostty |
| Shell | Bash |
| Editor | Neovim / LazyVim |
| Launcher | Rofi |
| File Manager | Yazi / Thunar |
| Wallpaper | swaybg |
| Lock Screen | Hyprlock |
| Idle Daemon | Hypridle |
| Notifications | SwayNC |
| Audio | PipeWire / EasyEffects |
| Network | NetworkManager / iwd |
| Bluetooth | BlueZ |
| System Monitor | btop |
| Media Visualizer | Cava |
| Git UI | Lazygit |
| AUR Helper | yay |
| CLI Navigation | zoxide / fzf |
| Image Viewer | Viewnior |
| PDF Viewer | MuPDF |

---

## License

This repository contains personal configuration files.

Use, modify, and adapt them as needed.

Some included configuration files originate from or are based on the default configurations of their respective applications and remain subject to their original licenses.
