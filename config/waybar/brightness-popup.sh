#!/bin/bash
# Brightness control popup using rofi

current=$(brightnessctl -m | cut -d',' -f4 | tr -d '%')

options="100%
75%
50%
25%
10%"

selected=$(echo -e "$options" | rofi -dmenu -i -p "Brightness: ${current}%" -theme-str 'window {width: 200px;}')

if [ -n "$selected" ]; then
    brightnessctl set "${selected}"
fi
