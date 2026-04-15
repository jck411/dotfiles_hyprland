#!/bin/bash
# reverse-tether.sh — toggle sharing laptop WiFi to phone via USB (gnirehtet)
# Used by SUPER+T keybind

set -e

notify() {
    notify-send -t 3000 "Reverse Tether" "$1"
}

# Check if gnirehtet is already running
if pgrep -x gnirehtet > /dev/null; then
    # Stop relay and VPN client on phone
    pkill -x gnirehtet 2>/dev/null
    adb shell am force-stop com.genymobile.gnirehtet 2>/dev/null
    notify "Stopped — phone disconnected from laptop WiFi"
    exit 0
fi

# Check ADB device is connected
if ! adb devices 2>/dev/null | grep -q "device$"; then
    notify "No phone connected via USB (or not authorized)"
    exit 1
fi

# Kill any stale VPN client on the phone from a previous session
adb shell am force-stop com.genymobile.gnirehtet 2>/dev/null
sleep 1

# Exempt from battery optimization (idempotent)
adb shell dumpsys deviceidle whitelist +com.genymobile.gnirehtet > /dev/null 2>&1

# Start gnirehtet in autorun mode (auto-reconnects on drop)
nohup gnirehtet autorun > /dev/null 2>&1 &
disown

notify "Started — sharing laptop WiFi to phone"
