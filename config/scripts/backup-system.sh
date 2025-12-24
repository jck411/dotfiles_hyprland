#!/bin/bash
# System backup: Timeshift snapshot + dotfiles git sync
# For installing/updating packages, use update-system.sh
#
# Usage: backup-system.sh

set -e

DOTFILES_DIR="$HOME/REPOS/dotfiles_hyprland"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         System Backup                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# =============================================================================
# PART 1: Timeshift Snapshot
# =============================================================================

echo -e "${CYAN}=== [1/2] Creating Timeshift Snapshot ===${NC}"

COMMENT="Manual backup $(date '+%Y-%m-%d %H:%M')"

if sudo timeshift --create --comments "$COMMENT" --tags D; then
    echo -e "${GREEN}✓ Timeshift snapshot created${NC}"
else
    echo -e "${RED}✗ Timeshift snapshot failed${NC}"
    exit 1
fi

echo

# =============================================================================
# PART 2: Dotfiles Sync & Backup
# =============================================================================

echo -e "${CYAN}=== [2/2] Syncing Dotfiles ===${NC}"

if [ -d "$DOTFILES_DIR" ] && [ -x "$DOTFILES_DIR/sync.sh" ]; then
    # Fix any broken symlinks
    "$DOTFILES_DIR/sync.sh" fix 2>/dev/null || true
    
    # Show status (new/orphaned configs)
    echo ""
    "$DOTFILES_DIR/sync.sh" status
    
    # Auto-commit any changes
    echo -e "\nCommitting dotfiles changes..."
    cd "$DOTFILES_DIR"
    
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Backup: $(date '+%Y-%m-%d %H:%M')" || true
        echo -e "${GREEN}✓ Dotfiles changes committed${NC}"
        
        # Push if remote exists and is configured
        if git remote get-url origin &>/dev/null; then
            if git push origin main; then
                echo -e "${GREEN}✓ Pushed to remote${NC}"
            else
                echo -e "${YELLOW}⚠ Push failed (offline or auth issue?)${NC}"
            fi
        fi
    else
        echo -e "${GREEN}✓ No dotfiles changes to commit${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Dotfiles repo not found at $DOTFILES_DIR${NC}"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Backup Complete!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo "Summary:"
echo "  • Timeshift snapshot created"
echo "  • Dotfiles synced & committed"
