#!/bin/bash
# Turn off displays via DPMS only when docked AND screensaver is enabled.
# Called by hypridle. When undocked or screensaver disabled, does nothing.

CONFIG_FILE="$HOME/.config/power-settings.conf"

# Check if screensaver is enabled in settings
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
[[ "$SCREENSAVER_ENABLED" != "true" ]] && exit 0

# Check if docked (external monitor connected)
for connector in /sys/class/drm/card*-*; do
    name=$(basename "$connector")
    [[ "$name" == *eDP* ]] && continue
    [[ "$name" == *Writeback* ]] && continue
    if [[ "$(cat "$connector/status" 2>/dev/null)" == "connected" ]]; then
        hyprctl dispatch dpms off
        exit 0
    fi
done
