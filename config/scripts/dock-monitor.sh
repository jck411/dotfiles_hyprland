#!/bin/bash
# dock-monitor.sh — OLED burn-in protection when docked
#
# Watches Hyprland IPC for monitor connect/disconnect events.
# When docked (external display active):  hides Waybar
# When undocked (back to laptop only):    restores Waybar
#
# Launched by Hyprland exec-once — auto-restarts if socket drops.

set -e

STATE_FILE="$HOME/.cache/dock-monitor.state"

# Returns 0 (true) if any external non-laptop display is connected
is_docked() {
    for connector in /sys/class/drm/card*-*; do
        name=$(basename "$connector")
        [[ "$name" == *eDP* ]] && continue
        [[ "$name" == *Writeback* ]] && continue
        [[ "$(cat "$connector/status" 2>/dev/null)" == "connected" ]] && return 0
    done
    return 1
}

hide_waybar() {
    [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "hidden" ]] && return
    pkill -SIGUSR1 waybar 2>/dev/null || true
    echo "hidden" > "$STATE_FILE"
    notify-send -i display "Docked — OLED protection" "Waybar hidden. Hover top edge to reveal." -t 3000 2>/dev/null || true
}

show_waybar() {
    [[ "$(cat "$STATE_FILE" 2>/dev/null)" != "hidden" ]] && return
    pkill -SIGUSR1 waybar 2>/dev/null || true
    echo "visible" > "$STATE_FILE"
    notify-send -i display "Undocked" "Waybar restored." -t 2000 2>/dev/null || true
}

# Set initial state on startup
if is_docked; then
    hide_waybar
else
    # Clear stale hidden state from previous session
    echo "visible" > "$STATE_FILE"
fi

# Wait for Hyprland IPC socket
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
while [[ ! -S "$SOCKET" ]]; do sleep 1; done

# Listen for monitor events
socat -u UNIX-CONNECT:"$SOCKET" - | while IFS= read -r line; do
    case "$line" in
        monitoradded*)
            sleep 1  # brief wait for display to fully initialise
            is_docked && hide_waybar
            ;;
        monitorremoved*)
            sleep 0.5
            is_docked || show_waybar
            ;;
    esac
done
