# Copilot Instructions — dotfiles_hyprland

Configuration-only dotfiles repo for EndeavourOS (Arch) + Hyprland (Wayland). Manages configs via symlinks — does NOT install packages or manage dependencies.

## Architecture

- Machine-specific values NEVER go in `hyprland.conf` — use `config/hypr/hosts/`
- New app = add to `packages/base.txt` (or host list) + config to `config/` in one commit
- Package lists in `packages/` pair with configs — keep them in sync

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
