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
