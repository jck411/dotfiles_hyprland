#!/bin/bash
# waybar-autohide.sh — cursor-position-based autohide for waybar on Hyprland
#
# Waybar's built-in "mode: hide" requires Sway IPC and does NOT work on Hyprland.
# This script polls hyprctl cursorpos and shows/hides waybar via signals:
#   SIGUSR1 → show (configured in waybar config)
#   SIGUSR2 → hide (configured in waybar config)
#
# Usage: waybar-autohide.sh &
# Kill with: pkill -f waybar-autohide

POLL_INTERVAL=0.1
EDGE_PX=2        # cursor within this many pixels of a monitor's top edge triggers show
LEAVE_PX=60      # cursor must move this far from top edge to trigger hide

state="hidden"   # start assumes waybar is hidden (start_hidden=true in config)

# Build array of monitor top-Y values (global coords) at startup
get_monitor_tops() {
    monitor_tops=()
    while IFS= read -r top_y; do
        [[ "$top_y" =~ ^[0-9]+$ ]] && monitor_tops+=("$top_y")
    done < <(hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if not m.get('disabled', False):
        print(m['y'])
" 2>/dev/null)
}

get_monitor_tops

while true; do
    raw=$(hyprctl cursorpos 2>/dev/null) || { sleep 1; continue; }
    # Parse "1234, 567" format — extract Y coordinate
    cy="${raw##*, }"
    # Validate it's a number
    [[ "$cy" =~ ^[0-9]+$ ]] || { sleep "$POLL_INTERVAL"; continue; }

    near_top=false
    for top in "${monitor_tops[@]}"; do
        if (( cy >= top && cy <= top + EDGE_PX )); then
            near_top=true
            break
        fi
    done

    if [[ "$near_top" == true && "$state" == "hidden" ]]; then
        pkill -x -SIGUSR1 waybar 2>/dev/null || true
        state="visible"
    elif [[ "$near_top" == false && "$state" == "visible" ]]; then
        # Only hide if we've moved far enough from ALL top edges
        far_from_all=true
        for top in "${monitor_tops[@]}"; do
            if (( cy >= top && cy <= top + LEAVE_PX )); then
                far_from_all=false
                break
            fi
        done
        if [[ "$far_from_all" == true ]]; then
            pkill -x -SIGUSR2 waybar 2>/dev/null || true
            state="hidden"
        fi
    fi

    sleep "$POLL_INTERVAL"
done
