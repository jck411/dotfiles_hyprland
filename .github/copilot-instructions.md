# Copilot Instructions — dotfiles_hyprland

Configuration-only dotfiles repo for EndeavourOS (Arch) + Hyprland (Wayland). Manages configs via symlinks — does NOT install packages or manage dependencies.

## Architecture

- `config/` symlinks to `~/.config/<app>`, `shell/` symlinks to `~/`
- `install.sh` creates symlinks + selects host profile; `sync.sh` adds/removes/checks configs
- `packages/` holds declarative package lists: `base.txt` + per-host (e.g. `dell-xps-13.txt`)
- `packages.sh` diffs declared packages vs installed — shows missing/extra, optionally installs
- `config/hypr/hosts/` holds per-machine profiles (GPU, monitor, cursor size)
- `hyprland.conf` sources: `host.conf`, `monitors.conf`, `workspaces.conf`, `quake-rules.conf`
- Machine-specific values NEVER go in `hyprland.conf` — use host profiles
- When adding a new app: add to `packages/base.txt` (or host list), config to `config/`, commit together
- Live config edits automatically reflect in the repo

## Security

- NEVER track credentials: `gh/`, `rclone/`, anything with tokens or API keys
- NEVER track app data or Electron caches: browser profiles, `obsidian/`, IndexedDB dirs
- Check `sync.sh` IGNORE_LIST before adding new configs

## Shell Scripts

- Use `#!/bin/bash` and `set -e`
- Use existing color variables (RED, GREEN, YELLOW, BLUE, CYAN, BOLD, NC)
- Target Arch Linux — use `pacman`/`yay`, not apt or dnf

## Configs

- Theme is Nord throughout (colors, GTK, icons)
- Wayland-native options only — not X11
- Electron apps use `--ozone-platform-hint=auto` for Wayland
