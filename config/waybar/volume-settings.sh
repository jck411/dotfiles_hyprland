#!/bin/bash
# Volume Settings Dialog for Waybar (rofi-based)

get_volume() { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%'; }
is_muted() { pactl get-sink-mute @DEFAULT_SINK@ | grep -q "yes"; }

set_volume() { pactl set-sink-volume @DEFAULT_SINK@ "$1%"; }
toggle_mute() { pactl set-sink-mute @DEFAULT_SINK@ toggle; }

show_dialog() {
    local volume=$(get_volume)
    
    if is_muted; then
        mute_opt="● Muted (active)"
        unmute_opt="○ Unmute"
    else
        mute_opt="○ Mute"
        unmute_opt="● Unmuted (active)"
    fi
    
    options="Volume: ${volume}%\n─────────────\n${unmute_opt}\n${mute_opt}\n─────────────\nOpen Mixer"
    
    selected=$(echo -e "$options" | rofi -dmenu -i -p "Audio" -theme-str 'window {width: 250px;}')
    
    case "$selected" in
        *"Mute"*|*"Unmute"*)
            toggle_mute
            notify-send -i audio-volume-muted "Audio" "Toggled mute"
            ;;
        "Open Mixer")
            pavucontrol &
            ;;
    esac
}

show_dialog
