#!/bin/bash
# System cleanup script for EndeavourOS
# Safe to run periodically to free up disk space

set -e

echo "╔════════════════════════════════════════╗"
echo "║       EndeavourOS System Cleanup       ║"
echo "╚════════════════════════════════════════╝"
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_size() {
    du -sh "$1" 2>/dev/null | cut -f1 || echo "0"
}

# Track space before
BEFORE=$(df / --output=avail | tail -1)

echo "=== Cleaning package cache ==="
echo -e "${YELLOW}Before:${NC} $(show_size /var/cache/pacman/pkg/)"
sudo paccache -rk2  # Keep only last 2 versions
echo -e "${GREEN}After:${NC} $(show_size /var/cache/pacman/pkg/)"

echo -e "\n=== Removing orphan packages ==="
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    echo "$ORPHANS"
    sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
else
    echo "No orphans found"
fi

echo -e "\n=== Cleaning user cache ==="
echo -e "${YELLOW}Before:${NC} $(show_size ~/.cache/)"

# Safe cache directories to clean (older than 30 days)
find ~/.cache -type f -atime +30 -delete 2>/dev/null || true

# Specific large caches
rm -rf ~/.cache/yay/* 2>/dev/null || true
rm -rf ~/.cache/mozilla/firefox/*/cache2/* 2>/dev/null || true
rm -rf ~/.cache/BraveSoftware/Brave-Browser/*/Cache/* 2>/dev/null || true
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
rm -rf ~/.cache/pip/* 2>/dev/null || true

# VS Code caches (safe to remove)
rm -rf ~/.config/Code\ -\ Insiders/CachedExtensionVSIXs/* 2>/dev/null || true
rm -rf ~/.config/Code\ -\ Insiders/Cache/* 2>/dev/null || true
rm -rf ~/.config/Code\ -\ Insiders/CachedData/* 2>/dev/null || true

echo -e "${GREEN}After:${NC} $(show_size ~/.cache/)"

echo -e "\n=== Cleaning journal logs ==="
echo -e "${YELLOW}Before:${NC} $(journalctl --disk-usage 2>&1 | grep -oP '\d+\.?\d*[MGK]')"
sudo journalctl --vacuum-time=7d --vacuum-size=50M
echo -e "${GREEN}After:${NC} $(journalctl --disk-usage 2>&1 | grep -oP '\d+\.?\d*[MGK]')"

echo -e "\n=== Cleaning coredumps ==="
if [ -d /var/lib/systemd/coredump ]; then
    echo -e "${YELLOW}Before:${NC} $(show_size /var/lib/systemd/coredump/)"
    sudo rm -rf /var/lib/systemd/coredump/*
    echo -e "${GREEN}After:${NC} 0"
fi

echo -e "\n=== Emptying trash ==="
rm -rf ~/.local/share/Trash/* 2>/dev/null || true

# Track space after
AFTER=$(df / --output=avail | tail -1)
FREED=$(( (AFTER - BEFORE) / 1024 ))

echo -e "\n${GREEN}=== Cleanup complete! ===${NC}"
echo -e "Space freed: ${GREEN}${FREED} MB${NC}"
