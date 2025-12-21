#!/bin/bash
# Full system update + dotfiles sync - 100% automatic, zero prompts
# Requires: passwordless sudo configured
# Handles: packages, extensions, Antigravity, cache cleanup, dotfiles sync & commit

set -e

DOTFILES_DIR="$HOME/REPOS/dotfiles_hyprland"

echo "╔════════════════════════════════════════╗"
echo "║    Automatic System Update & Backup    ║"
echo "╚════════════════════════════════════════╝"
echo

# =============================================================================
# PART 1: SYSTEM UPDATES
# =============================================================================

# 1. System packages (official + AUR)
echo "=== [1/7] Updating system packages ==="
yay -Syu --noconfirm

# 2. VS Code Insiders extensions
echo -e "\n=== [2/7] Updating VS Code Insiders extensions ==="
code-insiders --update-extensions 2>/dev/null || true

# 3. Tarball packages (Antigravity, etc. - reads from profile.json)
echo -e "\n=== [3/7] Updating tarball packages ==="
~/.config/scripts/update-tarballs.sh || true

# 4. Clean package cache (keep last 3 versions)
echo -e "\n=== [4/7] Cleaning package cache ==="
sudo paccache -r --noconfirm 2>/dev/null || sudo paccache -r

# 5. Remove orphan packages
echo -e "\n=== [5/7] Removing orphan packages ==="
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
else
    echo "No orphans found"
fi

# =============================================================================
# PART 2: DOTFILES SYNC & BACKUP
# =============================================================================

echo -e "\n=== [6/7] Syncing dotfiles ==="

if [ -d "$DOTFILES_DIR" ] && [ -x "$DOTFILES_DIR/sync.sh" ]; then
    # Fix any broken symlinks
    "$DOTFILES_DIR/sync.sh" fix 2>/dev/null || true
    
    # Show status (new/orphaned configs)
    echo ""
    "$DOTFILES_DIR/sync.sh" status
    
    # Auto-commit any changes
    echo -e "\n=== [7/7] Committing dotfiles changes ==="
    cd "$DOTFILES_DIR"
    
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M')" || true
        echo "✓ Dotfiles changes committed"
        
        # Push if remote exists and is configured
        if git remote get-url origin &>/dev/null; then
            git push 2>/dev/null && echo "✓ Pushed to remote" || echo "⚠ Push failed (offline?)"
        fi
    else
        echo "✓ No dotfiles changes to commit"
    fi
else
    echo "⚠ Dotfiles repo not found at $DOTFILES_DIR"
fi

# Update timestamp
date +%s > ~/.config/last_update_timestamp

echo -e "\n╔════════════════════════════════════════╗"
echo "║    Update & Backup Complete!           ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  • System packages updated"
echo "  • VS Code extensions updated"
echo "  • Antigravity checked"
echo "  • Package cache cleaned"
echo "  • Orphan packages removed"
echo "  • Dotfiles synced & committed"
echo ""
echo "Note: profile.json auto-updates via shell controller after package changes"
