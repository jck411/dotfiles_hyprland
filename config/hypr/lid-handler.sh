#!/bin/bash
# Lid close/open handler for Hyprland
# Reads action from power-settings.conf
# When docked (external display connected), lid close is always ignored.

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
        # When docked, ignore lid close — external display stays active
        if is_docked; then
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
        hyprctl dispatch dpms on
        ;;
esac
