#!/bin/bash
# Power profile selector using rofi

BATTERY_PATH="/sys/class/power_supply/BAT0"
CONFIG_FILE="$HOME/.config/power-settings.conf"

# Load or create config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Defaults
        SCREENSAVER_ENABLED="true"
        SCREENSAVER_TIMEOUT="300"
        AUTO_LOGOFF_ENABLED="false"
        AUTO_LOGOFF_TIMEOUT="600"
        LID_CLOSE_ACTION="suspend"
        save_config
    fi
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
SCREENSAVER_ENABLED="$SCREENSAVER_ENABLED"
SCREENSAVER_TIMEOUT="$SCREENSAVER_TIMEOUT"
AUTO_LOGOFF_ENABLED="$AUTO_LOGOFF_ENABLED"
AUTO_LOGOFF_TIMEOUT="$AUTO_LOGOFF_TIMEOUT"
LID_CLOSE_ACTION="$LID_CLOSE_ACTION"
EOF
}

apply_settings() {
    # Apply screensaver settings via swayidle or hypridle
    if [[ "$SCREENSAVER_ENABLED" == "true" ]]; then
        # Enable screen timeout (you may need to adjust for your idle daemon)
        notify-send "Power Settings" "Screensaver: ON (${SCREENSAVER_TIMEOUT}s)"
    else
        notify-send "Power Settings" "Screensaver: OFF"
    fi
    
    # Lid close action (requires logind config or hyprland bindl)
    # This is informational - actual implementation depends on your setup
}

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

    selected=$(echo -e "$options" | rofi -dmenu -i -p "Power Profile" -theme-str 'window {width: 280px;}')

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
