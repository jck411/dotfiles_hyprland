#!/bin/bash
# Power profile selector using rofi

show_advanced() {
    python3 ~/.config/waybar/power-settings-gui.py
}

show_dialog() {
    current=$(powerprofilesctl get)

    # Build options with active indicator
    options=""
    for profile in power-saver balanced performance; do
        if [[ "$profile" == "$current" ]]; then
            options+="● ${profile}\n"
        else
            options+="○ ${profile}\n"
        fi
    done
    options+="─────────────\nAdvanced"

    selected=$(echo -e "$options" | rofi -dmenu -i -p "Power Profile" -theme waybar)

    if [ -n "$selected" ]; then
        case "$selected" in
            "Advanced")
                show_advanced
                ;;
            *)
                # Extract profile name
                profile=$(echo "$selected" | sed 's/^[●○] //' | cut -d' ' -f1)
                if [[ "$profile" != "$current" ]]; then
                    powerprofilesctl set "$profile"
                    notify-send "Power Profile" "Switched to: $profile" -i battery
                fi
                ;;
        esac
    fi
}

case "$1" in
    --advanced) show_advanced ;;
    *)          show_dialog ;;
esac
