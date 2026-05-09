# Copilot Instructions — dotfiles_hyprland

Configuration-only dotfiles repo for EndeavourOS (Arch) + Hyprland (Wayland). Manages configs via symlinks — does NOT install packages or manage dependencies.

## Core Operating Principles

- **Zero legacy leftovers** — remove `.bak` files, stale configs, orphaned symlinks, and unused package entries; never leave dead files behind
- **Package lists and configs stay in sync** — always update both together in one commit; a package entry without config (or vice versa) is a bug
- **Docs must stay current** — keep `README` and instructions accurate; no duplicate or stale documentation
- **Protect sensitive files** — never track credentials, tokens, browser profiles, app data, or Electron caches

## Architecture

- Machine repos (`machine-dell-xps13`, etc.) are the entry points — this repo is edited from there
- Host profiles: `packages/<host>.txt` for packages, `config/hypr/hosts/<host>.conf` for Hyprland overrides
- Active hosts: `thinkpad-p16s-gen4`
- Machine-specific values NEVER go in `hyprland.conf` — use `config/hypr/hosts/`
- New app = add to `packages/base.txt` (or host list) + config to `config/` in one commit
- Package lists in `packages/` pair with configs — keep them in sync

## Scripts

- `packages.sh install <host>` — install base + host-specific packages
- `packages.sh status <host>` — show missing/extra packages
- `install.sh <component>` — symlink a config component to `~/.config/`
- `sync.sh status` — check symlink health
- `sync.sh fix` — repair broken symlinks
- Check `sync.sh` IGNORE_LIST before adding new configs

## Configs

- Theme is Nord throughout — match existing hex values
- Wayland-native options only — never X11
- Electron apps use `--ozone-platform-hint=auto`

## Security

- Never track credentials: `gh/`, `rclone/`, anything with tokens or API keys
- Never track app data or Electron caches: browser profiles, `obsidian/`, IndexedDB dirs

## After Change Checklist

Every meaningful change must satisfy:
- [ ] No `.bak` files, dead configs, or stale symlinks left behind
- [ ] Package list updated alongside any config change (keep in sync)
- [ ] Run `sync.sh status` to verify symlink health
- [ ] `.gitignore` updated for any new sensitive or local artifacts
- [ ] Committed and pushed

## Shell Scripts

- Use `#!/bin/bash` and `set -e`
- Use existing color variables (RED, GREEN, YELLOW, BLUE, CYAN, BOLD, NC)
- Target Arch Linux — use `pacman`/`yay`, not apt or dnf
