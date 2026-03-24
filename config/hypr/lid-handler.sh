#!/bin/bash
# Lid close/open handler for Hyprland
# Reads dock-aware settings from power-settings.conf
# When docked: ALWAYS disables laptop display (only external used), then runs configured action
# When undocked: runs UNDOCKED_LID_CLOSE_ACTION (default: poweroff)

CONFIG_FILE="$HOME/.config/power-settings.conf"

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Defaults if config missing
DOCKED_LID_CLOSE_ACTION="${DOCKED_LID_CLOSE_ACTION:-ignore}"
UNDOCKED_LID_CLOSE_ACTION="${UNDOCKED_LID_CLOSE_ACTION:-poweroff}"

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
            # Always disable laptop display when docked — only external is used
            hyprctl keyword monitor "eDP-1,disable" 2>/dev/null
            case "$DOCKED_LID_CLOSE_ACTION" in
                suspend)  systemctl suspend ;;
                lock)     hyprlock || loginctl lock-session ;;
                poweroff) systemctl poweroff ;;
                ignore)   ;;
            esac
        else
            case "$UNDOCKED_LID_CLOSE_ACTION" in
                suspend)  systemctl suspend ;;
                lock)     hyprlock || loginctl lock-session ;;
                poweroff) systemctl poweroff ;;
                ignore)   ;;
            esac
        fi
        ;;
    open)
        if is_docked; then
            # Re-enable laptop as secondary display
            hyprctl keyword monitor "eDP-1,preferred,auto,1" 2>/dev/null
        fi
        hyprctl dispatch dpms on
        ;;
esac
