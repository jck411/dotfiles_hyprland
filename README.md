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

### Core Configs

| Component | Description |
|-----------|-------------|
| `hypr/` | Hyprland window manager config |
| `waybar/` | Status bar config, scripts, and styling |
| `foot/` | Terminal emulator config |
| `foot-quake/` | Drop-down quake-style terminal |
| `rofi/` | Application launcher config |
| `mako/` | Notification daemon config |
| `gtk-3.0/` | GTK3 theme settings |
| `gtk-4.0/` | GTK4 theme settings |
| `Thunar/` | File manager |
| `imv/` | Image viewer |
| `mpv/` | Video player |
| `networkmanager-dmenu/` | WiFi menu |
| `nwg-displays/` | Display configuration GUI |
| `xdg-desktop-portal/` | Wayland portal config |
| `scripts/` | System maintenance scripts |
| `shell/` | Shell configs (.bashrc, .zshrc, .Xresources) |

### Standalone Config Files

| File | Description |
|------|-------------|
| `brave-flags.conf` | Brave browser Wayland flags |
| `code-flags.conf` | VS Code Wayland flags |
| `cursor-flags.conf` | Cursor editor Wayland flags |
| `electron-flags.conf` | General Electron app flags |
| `power-settings.conf` | Power management settings |

### Host Profiles (`hypr/hosts/`)

Machine-specific settings (GPU drivers, monitor config, cursor size) are
extracted into host profiles so the same dotfiles work across different hardware:

| Profile | Description |
|---------|-------------|
| `default.conf` | Safe fallback for any machine |
| `dell-xps-13.conf` | Dell XPS 13 — Intel Iris, 3200x1800 HiDPI |

## How It Works

```
~/.config/hypr/ ──symlink──▶ ~/REPOS/dotfiles_hyprland/config/hypr/
~/.config/waybar/ ──symlink──▶ ~/REPOS/dotfiles_hyprland/config/waybar/
~/.bashrc ──symlink──▶ ~/REPOS/dotfiles_hyprland/shell/.bashrc
```

Configs are symlinked, not copied. Any changes you make on the live system are automatically reflected in the repo.

## Installation

### Quick Install (symlinks all configs)
```bash
./install.sh
```

During install you'll be prompted to select a host profile for your machine.

### Install Specific Component
```bash
./install.sh hypr
./install.sh waybar
./install.sh brave-flags.conf
```

### Change Host Profile
```bash
./install.sh host
```

### Backup Only (no symlinks)
```bash
./install.sh --backup-only
```

### Adding a New Machine
```bash
cp config/hypr/hosts/default.conf config/hypr/hosts/my-laptop.conf
# Edit with your GPU, monitor, and cursor settings
./install.sh host    # Select the new profile
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
