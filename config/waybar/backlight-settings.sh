#!/bin/bash
# Backlight Settings Dialog for Waybar (rofi-based)

get_brightness() {
    local current=$(brightnessctl get)
    local max=$(brightnessctl max)
    echo $((current * 100 / max))
}

set_brightness() { brightnessctl set "$1%" -q; }

show_dialog() {
    local current=$(get_brightness)
    
    options="Current: ${current}%\n─────────────\n100%\n75%\n50%\n25%\n10%"
    
    selected=$(echo -e "$options" | rofi -dmenu -i -p "Brightness" -theme-str 'window {width: 200px;}')
    
    case "$selected" in
        "100%"|"75%"|"50%"|"25%"|"10%")
            set_brightness "${selected%\%}"
            notify-send -i display-brightness "Brightness" "Set to $selected"
            ;;
    esac
}

show_dialog
