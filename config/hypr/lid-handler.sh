#!/bin/bash
# Lid close/open handler for Hyprland
# Reads action from power-settings.conf

CONFIG_FILE="$HOME/.config/power-settings.conf"

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LID_CLOSE_ACTION="suspend"
fi

case "$1" in
    close)
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
        # Optional: actions when lid opens
        # e.g., turn on display
        hyprctl dispatch dpms on
        ;;
esac
