# ark-dotfiles

My personal Arch Linux + Hyprland dotfiles.

This repository contains the configuration, scripts, package lists, and system configuration used to build my current Wayland desktop environment.

The setup is centered around:

- Arch Linux
- Hyprland
- Waybar
- Ghostty
- Neovim / LazyVim
- Rofi
- Yazi
- Hyprlock
- Hypridle
- Hyprglass
- Dynamic wallpaper-based theming
- SDDM / greetd configuration
- Kew
- EasyEffects
- CLI utilities and development tools

---

## Repository Structure

```text
ark-dotfiles/
├── home/
│   ├── .aliases
│   ├── .bash_profile
│   ├── .bashrc
│   ├── .gitconfig
│   ├── .profile
│   │
│   ├── .config/
│   │   ├── btop/
│   │   ├── cava/
│   │   ├── easyeffectsrc
│   │   ├── environment.d/
│   │   ├── fastfetch/
│   │   ├── ghostty/
│   │   ├── gtk-3.0/
│   │   ├── gtk-4.0/
│   │   ├── hypr/
│   │   ├── kew/
│   │   ├── lazygit/
│   │   ├── mimeapps.list
│   │   ├── nvim/
│   │   ├── nwg-look/
│   │   ├── rofi/
│   │   ├── walltheme/
│   │   ├── waybar/
│   │   ├── wlogout/
│   │   ├── xsettingsd/
│   │   └── yazi/
│   │
│   └── .local/
│       └── bin/
│           ├── change_wall_on_key.sh
│           ├── hyprlock-wallpaper.sh
│           ├── killwaybar.sh
│           ├── set_current_wall.sh
│           ├── toggle_Waybar.sh
│           ├── update.sh
│           └── walltheme
│
├── packages/
│   ├── pacman.txt
│   ├── aur.txt
│   ├── flatpak.txt
│   └── npm.txt
│
├── system/
│   ├── greetd/
│   └── sddm/
│
├── .gitignore
└── README.md
```

---

# Desktop

## Hyprland

Hyprland is the compositor and window manager at the center of the setup.

The configuration is split into Lua modules:

```text
~/.config/hypr/
├── hyprland.lua
├── env.lua
├── monitors.lua
├── appearance.lua
├── apps.lua
├── keybinds.lua
├── hyprland-gui.lua
├── hyprglass.lua
├── walltheme.lua
├── hypridle.conf
├── hyprlock.conf
└── hyprpaper.conf
```

The main configuration imports the individual modules rather than keeping everything in a single file.

### Autostart

The Hyprland configuration starts several services and utilities automatically, including:

- `hypridle`
- Waybar
- Dynamic wallpaper/theme initialization
- EasyEffects
- `wl-paste` / `cliphist`
- Polkit authentication agent
- Thunar daemon
- Hyprsession
- Hyprglass

---

# Dynamic Wallpaper Theming

One of the main features of this setup is the dynamic theming system.

The wallpaper determines the color palette used throughout the desktop.

```text
Wallpaper
    │
    ▼
walltheme.py
    │
    ▼
current.json
    │
    ├──► Waybar CSS
    ├──► Ghostty theme
    ├──► Hyprlock config
    └──► Hyprland colors
```

The main components are located at:

```text
~/.config/walltheme/
├── walltheme.py
├── config.toml
├── generate-waybar.py
├── generate-ghostty.py
├── generate-hyprland.py
└── generate-hyprlock.py
```

The executable entry point is:

```text
~/.local/bin/walltheme
```

Usage:

```bash
walltheme ~/Wall/Wall1.png
```

This:

1. Extracts colors from the wallpaper.
2. Generates the theme palette.
3. Generates Waybar colors.
4. Generates the Ghostty theme.
5. Generates the Hyprlock configuration.
6. Reloads Hyprland.
7. Reloads running Ghostty instances.
8. Restarts Waybar.

Generated runtime files are intentionally excluded from Git:

```text
~/.config/walltheme/current.json
~/.config/walltheme/generated/
```

---

# Wallpaper System

Wallpapers are expected to live in:

```text
~/Wall/
```

The current setup uses:

```text
Wall1.png
Wall2.png
...
Wall14.png
```

Wallpaper state is stored separately from the dotfiles:

```text
~/.local/state/walltheme/.wall_state
```

This keeps machine-specific runtime state out of Git.

## Change Wallpaper

The wallpaper switching script is:

```bash
~/.local/bin/change_wall_on_key.sh
```

It:

1. Finds the available wallpapers.
2. Determines the next wallpaper.
3. Updates the wallpaper state.
4. Starts `swaybg`.
5. Updates the Hyprlock wallpaper symlink.
6. Runs `walltheme`.

The active Hyprlock wallpaper is represented by:

```text
~/Wall/hyprlock-wallpaper.png
```

This is a symlink to the currently selected wallpaper.

That means Hyprlock does not contain a hard-coded wallpaper path.

---

# Waybar

Waybar is configured using:

```text
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
```

The main stylesheet imports the generated wallpaper theme.

Waybar includes modules for things such as:

- Workspaces
- Window title
- Media controls
- CPU
- Memory
- Battery
- Network
- Bluetooth
- Audio
- Notifications
- Clock
- Power

---

# Ghostty

Ghostty is the primary terminal emulator.

Configuration:

```text
~/.config/ghostty/config
```

The generated wallpaper theme is loaded separately:

```text
~/.config/walltheme/generated/ghostty.conf
```

The wallpaper theme system sends `SIGUSR2` to running Ghostty processes so the theme can update without manually restarting every terminal.

---

# Shell

The shell is Bash.

Configuration:

```text
~/.bashrc
~/.bash_profile
~/.profile
~/.aliases
```

Included utilities include:

- `zoxide`
- `yazi`
- `fastfetch`

The `yz` shell function opens Yazi and changes the current shell directory to the directory selected in Yazi.

---

# Neovim

The Neovim configuration is based on LazyVim.

Location:

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

Plugin state is represented by `lazy-lock.json` so the installed plugin versions can be reproduced.

---

# Package Lists

The repository separates packages by installation source.

```text
packages/
├── pacman.txt
├── aur.txt
├── flatpak.txt
└── npm.txt
```

## Official Arch Packages

```bash
sudo pacman -S --needed - < packages/pacman.txt
```

## AUR Packages

Using `yay`:

```bash
yay -S --needed - < packages/aur.txt
```

## Flatpak Applications

```bash
while read -r app; do
    flatpak install -y flathub "$app"
done < packages/flatpak.txt
```

## NPM Packages

```bash
npm install -g $(tr '\n' ' ' < packages/npm.txt)
```

---

# System Configuration

System-level configuration is kept separately from user configuration.

```text
system/
├── greetd/
│   ├── config.toml
│   └── regreet.toml
│
└── sddm/
    ├── theme.conf
    └── wallpaper.conf
```

These files should **not** be copied blindly over an existing system.

Review them first and adapt paths, display-manager configuration, and permissions as necessary.

---

# Installation

## 1. Clone the Repository

```bash
git clone <YOUR-REPOSITORY-URL> ~/ark-dotfiles
cd ~/ark-dotfiles
```

---

## 2. Install Packages

Install official packages:

```bash
sudo pacman -S --needed - < packages/pacman.txt
```

Install AUR packages:

```bash
yay -S --needed - < packages/aur.txt
```

Install Flatpak applications:

```bash
while read -r app; do
    flatpak install -y flathub "$app"
done < packages/flatpak.txt
```

Install NPM packages:

```bash
npm install -g $(tr '\n' ' ' < packages/npm.txt)
```

---

## 3. Back Up Existing Configuration

Before installing the dotfiles:

```bash
mkdir -p ~/dotfiles-backup

cp -a ~/.config ~/dotfiles-backup/config
cp -a ~/.local/bin ~/dotfiles-backup/bin 2>/dev/null || true
cp -a ~/.bashrc ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.bash_profile ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.profile ~/dotfiles-backup/ 2>/dev/null || true
```

---

# Installing the Dotfiles

The repository mirrors the home directory structure.

For example:

```text
repository:
home/.config/hypr/hyprland.lua

installed location:
~/.config/hypr/hyprland.lua
```

A simple installation method is:

```bash
cp -a home/.config/. ~/.config/
cp -a home/.local/. ~/.local/
cp -a home/.[!.]* ~/
```

**Review this before running it on another machine.**

For a fresh installation, a symlink-based setup may be preferable.

---

# Dynamic Theme First Run

After installing the configuration, make sure the wallpaper directory exists:

```bash
mkdir -p ~/Wall
```

Copy wallpapers into it:

```text
~/Wall/
├── Wall1.png
├── Wall2.png
├── ...
└── Wall14.png
```

Initialize the wallpaper state:

```bash
mkdir -p ~/.local/state/walltheme
echo 1 > ~/.local/state/walltheme/.wall_state
```

Then apply the theme:

```bash
walltheme ~/Wall/Wall1.png
```

---

# Hyprlock

Hyprlock's configuration is generated by the wallpaper theme system.

The generated configuration uses:

```text
~/Wall/hyprlock-wallpaper.png
```

as the wallpaper source.

The symlink should point to the currently active wallpaper:

```bash
ls -l ~/Wall/hyprlock-wallpaper.png
```

Changing wallpapers updates this symlink automatically.

---

# Updating the System

The repository includes:

```text
~/.local/bin/update.sh
```

and the Bash alias:

```bash
update
```

The script updates:

- Pacman packages
- AUR packages
- Flatpak applications

Run:

```bash
update
```

---

# Git Hygiene

This repository intentionally does **not** track:

- API keys
- Passwords
- Tokens
- Credentials
- `.env` files
- Authentication files
- Browser state
- Application databases
- Wallpaper state
- Generated theme files
- Other machine-specific runtime state

The `.gitignore` contains the relevant exclusions.

Before pushing changes, it is recommended to check:

```bash
git diff --check
```

and:

```bash
git status
```

For a quick credential-name check:

```bash
git diff --cached --name-only | grep -Ei \
'(\.env|secret|token|password|credential|auth\.json|hosts\.yml|\.pem|\.key)'
```

---

# Notes

## Machine-specific configuration

Some configuration may need adjustment when moving this setup to another machine.

In particular:

- Monitor names
- Monitor resolutions
- GPU-specific settings
- Display-manager configuration
- Wallpaper collection
- Hardware-specific audio settings
- Package availability
- Application paths

The configuration should therefore be treated as a **base environment**, not a completely hardware-independent installation script.

---

# Philosophy

The goal of this repository is to keep the important parts of the desktop reproducible while avoiding unnecessary runtime state.

Tracked:

```text
Configuration
Scripts
Themes
Package lists
System configuration
Neovim configuration
```

Not tracked:

```text
Secrets
Generated files
Caches
Application databases
Wallpaper state
Machine-specific runtime state
```

The result is a portable Arch Linux desktop configuration that can be rebuilt without copying the entire home directory.

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
