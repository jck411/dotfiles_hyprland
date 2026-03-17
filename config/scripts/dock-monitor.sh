#!/bin/bash
# dock-monitor.sh — monitor/workspace/waybar management for docked Hyprland
#
# Watches Hyprland IPC for monitor connect/disconnect events.
# When docked (external display detected):
#   - Positions monitors (external at 0,0, laptop below)
#   - Binds workspaces (1-7 → external, 8-10 → laptop)
#   - Starts waybar with autohide config
# When undocked:
#   - Kills autohide, restores normal waybar
#   - Clears workspace-monitor bindings
#
# Window layout is triggered manually via SUPER+SHIFT+D → dock-layout.sh
#
# Launched by Hyprland exec-once — auto-restarts if socket drops.
# No set -e: long-running daemon.

STATE_FILE="$HOME/.cache/dock-monitor.state"
WAYBAR_NORMAL="$HOME/.config/waybar/config.jsonc"
WAYBAR_DOCKED="$HOME/.config/waybar/config-docked.jsonc"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
AUTOHIDE_SCRIPT="$HOME/.config/scripts/waybar-autohide.sh"

# =============================================================================
# HARDWARE DETECTION
# =============================================================================

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

# Get the Hyprland name of the connected external monitor (e.g. DP-4)
get_external_monitor() {
    hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if 'eDP' not in m['name']:
        print(m['name'])
        break
" 2>/dev/null
}

# =============================================================================
# WAYBAR
# =============================================================================

restart_waybar() {
    local config="$1"
    killall waybar 2>/dev/null || true
    sleep 0.3
    waybar -c "$config" -s "$WAYBAR_STYLE" &
    disown
}

stop_autohide() {
    pkill -f "waybar-autohide" 2>/dev/null || true
}

start_autohide() {
    stop_autohide
    sleep 0.3
    "$AUTOHIDE_SCRIPT" &
    disown
}

# =============================================================================
# DOCKED LAYOUT (monitors + workspaces only — no window management)
# =============================================================================

apply_docked_layout() {
    local ext
    ext=$(get_external_monitor)
    [[ -z "$ext" ]] && return

    # Position: external at 0,0 — laptop centered below
    hyprctl keyword monitor "$ext,preferred,0x0,1" 2>/dev/null
    hyprctl keyword monitor "eDP-1,preferred,1600x1440,1" 2>/dev/null

    # Bind workspaces: 1-7 → external, 8-10 → laptop
    for ws in 1 2 3 4 5 6 7; do
        hyprctl keyword workspace "$ws,monitor:$ext" 2>/dev/null
    done
    for ws in 8 9 10; do
        hyprctl keyword workspace "$ws,monitor:eDP-1" 2>/dev/null
    done

    hyprctl dispatch workspace 1 2>/dev/null
}

clear_docked_layout() {
    for ws in 1 2 3 4 5 6 7 8 9 10; do
        hyprctl keyword workspace "$ws,monitor:" 2>/dev/null || true
    done
    hyprctl keyword monitor "eDP-1,preferred,auto,1" 2>/dev/null
}

# =============================================================================
# DOCK / UNDOCK TRANSITIONS
# =============================================================================

enter_docked() {
    [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "docked" ]] && return
    sleep 1  # let the display fully initialise
    apply_docked_layout
    restart_waybar "$WAYBAR_DOCKED"
    sleep 0.5
    start_autohide
    echo "docked" > "$STATE_FILE"
    notify-send -i display "Docked" "Autohide waybar → top edge\nPress SUPER+SHIFT+D to launch docked layout" -t 4000 2>/dev/null || true
}

enter_undocked() {
    [[ "$(cat "$STATE_FILE" 2>/dev/null)" != "docked" ]] && return
    stop_autohide
    clear_docked_layout
    restart_waybar "$WAYBAR_NORMAL"
    echo "undocked" > "$STATE_FILE"
    notify-send -i display "Undocked" "Waybar restored. Laptop only." -t 2000 2>/dev/null || true
}

# =============================================================================
# MAIN
# =============================================================================

# Set initial state on startup
if is_docked; then
    enter_docked
else
    echo "undocked" > "$STATE_FILE"
fi

# Wait for Hyprland IPC socket
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
while [[ ! -S "$SOCKET" ]]; do sleep 1; done

# Listen for monitor events
socat -u UNIX-CONNECT:"$SOCKET" - | while IFS= read -r line; do
    case "$line" in
        monitoradded*)
            is_docked && enter_docked
            ;;
        monitorremoved*)
            sleep 0.5
            is_docked || enter_undocked
            ;;
    esac
done
