#!/bin/bash
# System update — official + AUR packages via yay

echo "╔════════════════════════════════════════╗"
echo "║         System Update                  ║"
echo "╚════════════════════════════════════════╝"
echo

yay -Syu

# Update timestamp regardless of partial AUR failures
date +%s > ~/.config/last_update_timestamp

echo -e "\n✓ System update complete"

# Check Downloads for any tarball updates (sudo already cached from yay)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ""
echo "╔════════════════════════════════════════╗"
echo "║         Tarball Updates                ║"
echo "╚════════════════════════════════════════╝"
"$SCRIPT_DIR/update-tarballs.sh"
