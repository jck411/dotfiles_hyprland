#!/bin/bash
# dock-monitor.sh — auto-layout + autohide waybar for docked Hyprland
#
# Watches Hyprland IPC for monitor connect/disconnect events.
# When docked (external ultrawide detected):
#   - Positions monitors (external at 0,0, laptop below)
#   - Binds workspaces (1-7 → external, 8-10 → laptop)
#   - Launches 4-column layout on external: VSCode | ChatGPT | Calendar | Gmail
#   - Launches Spotify on laptop screen
#   - Starts waybar with autohide config
# When undocked:
#   - Kills autohide, restores normal waybar
#   - Clears workspace-monitor bindings
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

# Get the Hyprland name of the connected external monitor (e.g. DP-6)
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
# WINDOW MANAGEMENT HELPERS
# =============================================================================

# Get addresses of all windows matching a class
get_addrs_for_class() {
    hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    if '$1' in c.get('class', ''):
        print(c['address'])
" 2>/dev/null
}

# Wait for a new window of the given class (not in known_addrs list)
# Returns the new window's address, or empty string on timeout
wait_for_new_window() {
    local class="$1" known="$2"
    local i addr
    for i in $(seq 1 30); do
        addr=$(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
known = set('''$known'''.split())
for c in json.load(sys.stdin):
    if '$class' in c.get('class', '') and c['address'] not in known:
        print(c['address'])
        break
" 2>/dev/null)
        if [[ -n "$addr" ]]; then
            echo "$addr"
            return 0
        fi
        sleep 0.5
    done
    return 1
}

# =============================================================================
# DOCKED LAYOUT (monitors + workspaces)
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

    # Restore default dwindle settings
    hyprctl keyword dwindle:force_split 0 2>/dev/null
    hyprctl keyword dwindle:split_width_multiplier 1.0 2>/dev/null
}

# =============================================================================
# DOCKED WINDOW LAYOUT — 4 columns on ultrawide + Spotify on laptop
#
# Uses dwindle's binary tree with force_split=2 (always split right).
# Launch order + focus control creates 4 equal columns:
#   1. VSCode fills WS1
#   2. Calendar splits it: [VSCode 50% | Calendar 50%]
#   3. Focus VSCode, launch ChatGPT: [VSCode 25% | ChatGPT 25% | Calendar 50%]
#   4. Focus Calendar, launch Gmail: [VSCode 25% | ChatGPT 25% | Calendar 25% | Gmail 25%]
# =============================================================================

apply_docked_windows() {
    local ext
    ext=$(get_external_monitor)
    [[ -z "$ext" ]] && return 1

    # Force column splits on ultrawide (1280*1.5=1920 > 1440 → vertical split)
    hyprctl keyword dwindle:force_split 2 2>/dev/null
    hyprctl keyword dwindle:split_width_multiplier 1.5 2>/dev/null

    # Focus external monitor, workspace 1
    hyprctl dispatch focusmonitor "$ext" 2>/dev/null
    hyprctl dispatch workspace 1 2>/dev/null
    sleep 0.3

    local known_brave
    known_brave=$(get_addrs_for_class "brave-browser")

    # --- Column 1: VS Code (fills workspace 1) ---
    local vscode_addr
    vscode_addr=$(get_addrs_for_class "code-insiders" | head -1)
    if [[ -z "$vscode_addr" ]]; then
        code-insiders &>/dev/null &
        disown
        vscode_addr=$(wait_for_new_window "code-insiders" "") || true
    fi
    if [[ -n "$vscode_addr" ]]; then
        hyprctl dispatch movetoworkspacesilent "1,address:$vscode_addr" 2>/dev/null
        hyprctl dispatch focuswindow "address:$vscode_addr" 2>/dev/null
    fi
    sleep 1

    # --- Step 2: Calendar (splits: [VSCode | Calendar]) ---
    brave --new-window "https://calendar.google.com" &>/dev/null &
    disown
    local cal_addr
    cal_addr=$(wait_for_new_window "brave-browser" "$known_brave") || true
    known_brave="$known_brave $cal_addr"
    sleep 1

    # --- Step 3: Focus VSCode → launch ChatGPT → [VSCode | ChatGPT | Calendar] ---
    [[ -n "$vscode_addr" ]] && hyprctl dispatch focuswindow "address:$vscode_addr" 2>/dev/null
    sleep 0.3
    brave --new-window "https://chatgpt.com" &>/dev/null &
    disown
    local chat_addr
    chat_addr=$(wait_for_new_window "brave-browser" "$known_brave") || true
    known_brave="$known_brave $chat_addr"
    sleep 1

    # --- Step 4: Focus Calendar → launch Gmail → [VSCode | ChatGPT | Calendar | Gmail] ---
    [[ -n "$cal_addr" ]] && hyprctl dispatch focuswindow "address:$cal_addr" 2>/dev/null
    sleep 0.3
    brave --new-window "https://mail.google.com" &>/dev/null &
    disown
    local gmail_addr
    gmail_addr=$(wait_for_new_window "brave-browser" "$known_brave") || true
    sleep 1

    # --- Laptop: Spotify on workspace 8 ---
    local spot_addr
    spot_addr=$(get_addrs_for_class "spotify" | head -1)
    if [[ -z "$spot_addr" ]]; then
        spotify &>/dev/null &
        disown
        spot_addr=$(wait_for_new_window "spotify" "") || true
    fi
    [[ -n "$spot_addr" ]] && hyprctl dispatch movetoworkspacesilent "8,address:$spot_addr" 2>/dev/null

    # Restore split_width_multiplier (keep force_split=2 for consistent tiling)
    hyprctl keyword dwindle:split_width_multiplier 1.0 2>/dev/null

    # Focus workspace 1 on external
    hyprctl dispatch workspace 1 2>/dev/null
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
    apply_docked_windows
    echo "docked" > "$STATE_FILE"
    notify-send -i display "Docked" "4-column layout: VSCode | ChatGPT | Calendar | Gmail\nSpotify → laptop · Autohide waybar → top edge" -t 5000 2>/dev/null || true
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
