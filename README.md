# EndeavourOS Dotfiles

Personal dotfiles for EndeavourOS with Hyprland (Wayland) and Nord theme.

This repo **only manages configuration files** via symlinks. It does not install packages, manage dependencies, or track app data. Install apps with `yay`/`pacman` first, then use this repo to manage their configs.

## System Info

- **OS**: EndeavourOS (Arch-based)
- **WM**: Hyprland (Wayland)
- **Bar**: Waybar
- **Terminal**: Foot
- **Launcher**: Rofi
- **Notifications**: Mako
- **Theme**: Nord

## What's Included

### Core Configs (installed by `install.sh`)

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
| `shell/` | Shell configs (.bashrc, .zshrc, .Xresources) |

### Additional Configs (managed via `sync.sh add`)

| Component | Description |
|-----------|-------------|
| `foot-quake/` | Drop-down quake-style terminal |
| `Thunar/` | File manager |
| `imv/` | Image viewer |
| `mpv/` | Video player |
| `networkmanager-dmenu/` | WiFi menu |
| `nwg-displays/` | Display configuration GUI |
| `xdg-desktop-portal/` | Wayland portal config |
| `brave-flags.conf` | Brave browser Wayland flags |
| `code-flags.conf` | VS Code Wayland flags |
| `cursor-flags.conf` | Cursor editor Wayland flags |
| `electron-flags.conf` | General Electron app flags |
| `power-settings.conf` | Power management settings |

## How It Works

```
~/.config/hypr/ ──symlink──▶ ~/REPOS/dotfiles_hyprland/config/hypr/
~/.config/waybar/ ──symlink──▶ ~/REPOS/dotfiles_hyprland/config/waybar/
~/.bashrc ──symlink──▶ ~/REPOS/dotfiles_hyprland/shell/.bashrc
```

Configs are symlinked, not copied. Any changes you make on the live system are automatically reflected in the repo.

## Installation

### Quick Install (symlinks all core configs)
```bash
./install.sh
```

### Install Specific Component
```bash
./install.sh hypr
./install.sh waybar
```

### Backup Only (no symlinks)
```bash
./install.sh --backup-only
```

## Sync Management

Use `sync.sh` to manage configs beyond the core set:

```bash
./sync.sh status         # Show sync status and untracked configs
./sync.sh add <name>     # Add a config from ~/.config to the repo
./sync.sh remove <name>  # Remove a config from the repo
./sync.sh fix            # Fix all broken symlinks
./sync.sh interactive    # Interactive menu
```

### Workflow: Adding a New App Config
```bash
yay -S neovim              # 1. Install the app
# Configure it...           # 2. Use and customize
./sync.sh add nvim         # 3. Move config to repo + create symlink
git add -A && git commit   # 4. Commit to version control
```

## Dependencies

### Core (required)
```bash
yay -S hyprland waybar foot rofi mako
```

### Utilities (required for full functionality)
```bash
yay -S swww grim slurp swappy wl-clipboard cliphist brightnessctl
```

### Fonts & Themes (required for Nord theme)
```bash
yay -S ttf-commit-mono-nerd nordic-theme nordzy-icon-theme nordzy-cursors
```

### Optional Apps
```bash
yay -S thunar nwg-displays imv mpv networkmanager-dmenu
```

## Security

**Never track configs containing credentials.** The following are excluded in `sync.sh`:
- `gh/` — GitHub CLI OAuth tokens
- `rclone/` — Google Drive OAuth credentials
- `BraveSoftware/` — Browser profile data
- `google-chrome/` — Browser profile data

See the `IGNORE_LIST` in `sync.sh` for the full list.

## License

Feel free to use and modify as you like!
