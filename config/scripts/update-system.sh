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
echo "=== [1/6] Updating system packages ==="
yay -Syu --noconfirm

# 2. VS Code Insiders extensions
echo -e "\n=== [2/6] Updating VS Code Insiders extensions ==="
code-insiders --update-extensions 2>/dev/null || true

# 3. Tarball packages (Antigravity, etc. - reads from profile.json)
echo -e "\n=== [3/6] Updating tarball packages ==="
~/.config/scripts/update-tarballs.sh || true

# 4. Clean package cache (keep last 3 versions)
echo -e "\n=== [4/6] Cleaning package cache ==="
sudo paccache -r --noconfirm 2>/dev/null || sudo paccache -r

# 5. Remove orphan packages
echo -e "\n=== [5/6] Removing orphan packages ==="
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
else
    echo "No orphans found"
fi

# 6. Trim VS Code Insiders workspace storage to under 1 GB
echo -e "\n=== [6/6] Trimming VS Code workspace storage ==="
VSCODE_WS_DIR="$HOME/.config/Code - Insiders/User/workspaceStorage"
MAX_BYTES=$((1024 * 1024 * 1024))  # 1 GB
if [ -d "$VSCODE_WS_DIR" ]; then
    CURRENT_BYTES=$(du -sb "$VSCODE_WS_DIR" | awk '{print $1}')
    if [ "$CURRENT_BYTES" -gt "$MAX_BYTES" ]; then
        echo "  Current size: $(du -sh "$VSCODE_WS_DIR" | awk '{print $1}') — trimming to <1 GB"
        # Delete oldest-accessed folders first
        while [ "$CURRENT_BYTES" -gt "$MAX_BYTES" ]; do
            OLDEST=$(find "$VSCODE_WS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%A@ %p\n' \
                | sort -n | head -1 | cut -d' ' -f2-)
            [ -z "$OLDEST" ] && break
            SIZE=$(du -sh "$OLDEST" | awk '{print $1}')
            echo "  Removing $(basename "$OLDEST") ($SIZE)"
            rm -rf "$OLDEST"
            CURRENT_BYTES=$(du -sb "$VSCODE_WS_DIR" | awk '{print $1}')
        done
        echo "  Trimmed to $(du -sh "$VSCODE_WS_DIR" | awk '{print $1}')"
    else
        echo "  Size OK: $(du -sh "$VSCODE_WS_DIR" | awk '{print $1}') (under 1 GB)"
    fi
else
    echo "  Workspace storage dir not found — skipping"
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
echo "  • VS Code workspace storage trimmed"
echo ""
echo "To back up your configs, run: system_backup"
