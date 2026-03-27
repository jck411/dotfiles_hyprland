#!/bin/bash
# System update - installs/updates packages and apps
# For backups (including dotfiles), use backup-system.sh
#
# Handles: packages, extensions, tarball apps, cleanup

set -e

echo "╔════════════════════════════════════════╗"
echo "║         System Update                  ║"
echo "╚════════════════════════════════════════╝"
echo

# 1. System packages (official + AUR)
echo "=== [1/5] Updating system packages ==="
yay -Syu --noconfirm

# 2. VS Code Insiders extensions
echo -e "\n=== [2/5] Updating VS Code Insiders extensions ==="
code-insiders --update-extensions 2>/dev/null || true

# 3. Tarball packages (Antigravity, etc. - reads from profile.json)
echo -e "\n=== [3/5] Updating tarball packages ==="
~/.config/scripts/update-tarballs.sh || true

# 4. Clean package cache (keep last 3 versions)
echo -e "\n=== [4/5] Cleaning package cache ==="
sudo paccache -r --noconfirm 2>/dev/null || sudo paccache -r

# 5. Remove orphan packages
echo -e "\n=== [5/5] Removing orphan packages ==="
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
else
    echo "No orphans found"
fi

# Update timestamp
date +%s > ~/.config/last_update_timestamp

echo -e "\n╔════════════════════════════════════════╗"
echo "║         Update Complete!               ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  • System packages updated"
echo "  • VS Code extensions updated"
echo "  • Tarball apps checked"
echo "  • Package cache cleaned"
echo "  • Orphan packages removed"
echo ""
echo "To back up your configs, run: system_backup"
