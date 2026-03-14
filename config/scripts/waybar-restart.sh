#!/bin/bash
# waybar-restart.sh — dock-aware waybar restart
# Used by SUPER+B keybind and dock-monitor.sh

set -e

STATE_FILE="$HOME/.cache/dock-monitor.state"
WAYBAR_DOCKED="$HOME/.config/waybar/config-docked.jsonc"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
AUTOHIDE="$HOME/.config/scripts/waybar-autohide.sh"

pkill -f "waybar-autohide" 2>/dev/null || true
killall waybar 2>/dev/null || true
sleep 0.3

if [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "docked" ]]; then
    waybar -c "$WAYBAR_DOCKED" -s "$WAYBAR_STYLE" &
    disown
    sleep 0.5
    "$AUTOHIDE" &
    disown
else
    waybar &
    disown
fi
