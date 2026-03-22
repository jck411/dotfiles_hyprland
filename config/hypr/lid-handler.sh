#!/bin/bash
# Lid close/open handler for Hyprland
# Reads action from power-settings.conf
# When docked: lid close disables laptop display, lid open re-enables it.

CONFIG_FILE="$HOME/.config/power-settings.conf"

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LID_CLOSE_ACTION="poweroff"
fi

# Returns 0 (true) if any external display connector is connected
is_docked() {
    for connector in /sys/class/drm/card*-*; do
        name=$(basename "$connector")
        # Skip built-in display and non-display connectors
        [[ "$name" == *eDP* ]] && continue
        [[ "$name" == *Writeback* ]] && continue
        [[ "$(cat "$connector/status" 2>/dev/null)" == "connected" ]] && return 0
    done
    return 1
}

case "$1" in
    close)
        if is_docked; then
            # Disable laptop display — external stays active
            hyprctl keyword monitor "eDP-1,disable" 2>/dev/null
            exit 0
        fi
        case "$LID_CLOSE_ACTION" in
            suspend)
                systemctl suspend
                ;;
            lock)
                hyprlock || swaylock || loginctl lock-session
                ;;
            poweroff)
                systemctl poweroff
                ;;
            ignore)
                # Do nothing
                ;;
        esac
        ;;
    open)
        if is_docked; then
            # Re-enable laptop as secondary display
            hyprctl keyword monitor "eDP-1,preferred,auto,1" 2>/dev/null
        fi
        hyprctl dispatch dpms on
        ;;
esac
