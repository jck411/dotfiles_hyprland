#!/bin/bash
# Power actions menu (shutdown, logout, screensaver, etc.) using rofi

options="󰌾  Lock\n󰒲  Suspend\n󰍃  Logout\n󰜉  Reboot\n󰐥  Power Off"

selected=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme waybar -theme-str 'listview {lines: 5;}')

case "$selected" in
    "󰌾  Lock")
        # Lock screen using swaylock or hyprlock
        if command -v hyprlock &> /dev/null; then
            hyprlock
        elif command -v swaylock &> /dev/null; then
            swaylock -f
        else
            notify-send "Lock" "No lock program found (install hyprlock or swaylock)"
        fi
        ;;
    "󰒲  Suspend")
        # Lock first, then suspend
        if command -v hyprlock &> /dev/null; then
            hyprlock &
        elif command -v swaylock &> /dev/null; then
            swaylock -f &
        fi
        sleep 0.5
        systemctl suspend
        ;;
    "󰍃  Logout")
        hyprctl dispatch exit
        ;;
    "󰜉  Reboot")
        systemctl reboot
        ;;
    "󰐥  Power Off")
        systemctl poweroff
        ;;
esac
