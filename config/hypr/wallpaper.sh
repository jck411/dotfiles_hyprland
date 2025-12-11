#!/bin/bash
# Wallpaper rotation script using swww
# Rotates through wallpapers every 5 minutes with smooth transitions

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
INTERVAL=300  # 5 minutes in seconds

# swww transition settings (smooth fade)
TRANSITION_TYPE="fade"
TRANSITION_DURATION=2

# Wait for swww daemon
sleep 1

while true; do
    # Get random wallpaper
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | shuf -n 1)
    
    if [[ -n "$WALLPAPER" ]]; then
        swww img "$WALLPAPER" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-duration "$TRANSITION_DURATION"
    fi
    
    sleep $INTERVAL
done
