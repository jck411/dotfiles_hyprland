# EndeavourOS Dotfiles

My personal dotfiles for EndeavourOS with Hyprland (Wayland) and Nord theme.

## System Info
- **OS**: EndeavourOS (Arch-based)
- **WM**: Hyprland
- **Bar**: Waybar
- **Terminal**: Foot
- **Launcher**: Rofi
- **Notifications**: Mako
- **Theme**: Nord

## What's Included

| Component | Description |
|-----------|-------------|
| `hypr/` | Hyprland window manager config |
| `waybar/` | Status bar config, scripts, and styling |
| `foot/` | Terminal emulator config |
| `rofi/` | Application launcher config |
| `mako/` | Notification daemon config |
| `gtk-3.0/` | GTK3 theme settings |
| `gtk-4.0/` | GTK4 theme settings |
| `scripts/` | System maintenance scripts |
| `shell/` | Shell configs (.bashrc, .zshrc) |

## Installation

### Quick Install (symlinks everything)
```bash
./install.sh
```

### Manual Install
```bash
# Backup existing configs
./install.sh --backup-only

# Symlink specific component
./install.sh hypr
./install.sh waybar
```

## Dependencies

```bash
# Core
yay -S hyprland waybar foot rofi mako

# Utilities
yay -S swww grim slurp swappy wl-clipboard cliphist brightnessctl

# Fonts & Themes
yay -S ttf-commit-mono-nerd nordic-theme nordzy-icon-theme nordzy-cursors

# Optional
yay -S thunar nwg-displays
```

## Screenshots

<!-- Add your screenshots here -->

## License
Feel free to use and modify as you like!
