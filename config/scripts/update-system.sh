#!/bin/bash
# Full system update - 100% automatic, zero prompts
# Requires: passwordless sudo configured

set -e

echo "╔════════════════════════════════════════╗"
echo "║       Automatic System Update          ║"
echo "╚════════════════════════════════════════╝"
echo

# 1. System packages (official + AUR)
echo "=== Updating system packages ==="
yay -Syu --noconfirm

# 2. VS Code Insiders extensions
echo -e "\n=== Updating VS Code Insiders extensions ==="
code-insiders --update-extensions 2>/dev/null || true

# 3. Antigravity (if tarball exists in Downloads)
echo -e "\n=== Checking for Antigravity update ==="
~/.config/scripts/update-antigravity.sh || true

# 4. Clean package cache (keep last 3 versions)
echo -e "\n=== Cleaning package cache ==="
sudo paccache -r --noconfirm 2>/dev/null || sudo paccache -r

# 5. Remove orphan packages
echo -e "\n=== Removing orphan packages ==="
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
else
    echo "No orphans found"
fi

# 6. Update timestamp
date +%s > ~/.config/last_update_timestamp

echo -e "\n╔════════════════════════════════════════╗"
echo "║       Update complete!                 ║"
echo "╚════════════════════════════════════════╝"
