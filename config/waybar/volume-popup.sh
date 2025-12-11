#!/bin/bash
# Volume control popup using rofi (matches Nord theme)

current=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1)
muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'yes|no')

if [ "$muted" = "yes" ]; then
    status="[Muted]"
else
    status="$current"
fi

options="󰕾  100%
󰖀  75%
󰖀  50%
󰕿  25%
󰝟  Mute/Unmute
  Audio Settings"

selected=$(echo -e "$options" | rofi -dmenu -i -p "Vol: $status")

case "$selected" in
    *"100%"*)
        pactl set-sink-volume @DEFAULT_SINK@ 100%
        ;;
    *"75%"*)
        pactl set-sink-volume @DEFAULT_SINK@ 75%
        ;;
    *"50%"*)
        pactl set-sink-volume @DEFAULT_SINK@ 50%
        ;;
    *"25%"*)
        pactl set-sink-volume @DEFAULT_SINK@ 25%
        ;;
    *"Mute"*)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        ;;
    *"Audio Settings"*)
        pavucontrol &
        ;;
esac
