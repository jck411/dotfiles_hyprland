#!/bin/bash

echo "Starting system update (Native & AUR)..."
yay -Syu

echo "Updating VS Code Insiders extensions..."
code-insiders --update-extensions

echo "Cleaning up package cache (keeping last 3 versions)..."
sudo paccache -r

echo "Removing unused dependencies (orphans)..."
yay -Yc

# Update the timestamp
date +%s > ~/.config/last_update_timestamp
echo "System update and cleanup complete."
echo "Timestamp updated."
