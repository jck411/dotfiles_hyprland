#!/bin/bash
# dock-layout.sh — 4-column docked layout for ultrawide (external monitor only)
#
# Kills existing layout apps, then launches fresh:
#   VSCode | ChatGPT | Calendar | Gmail on workspace 1 (external)
#   Spotify on workspace 2 (external)
#
# Only runs when docked (external monitor detected). Bound to SUPER+SHIFT+D.
# Uses moveworkspacetomonitor to guarantee correct monitor placement.

set -e

# =============================================================================
# DETECT EXTERNAL MONITOR
# =============================================================================

get_external_monitor() {
    hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if 'eDP' not in m['name']:
        print(m['name'])
        break
" 2>/dev/null
}

EXT=$(get_external_monitor)
if [[ -z "$EXT" ]]; then
    notify-send -i display "Not docked" "No external monitor detected." -t 2000 2>/dev/null
    exit 0
fi

# =============================================================================
# HELPERS
# =============================================================================

# Get addresses of all windows matching a class
get_addrs() {
    hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    if '$1' in c.get('class', ''):
        print(c['address'])
" 2>/dev/null
}

# Wait for a new window (up to 15s)
wait_for_window() {
    local class="$1" known="$2"
    for _ in $(seq 1 30); do
        local addr
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

# Close all windows matching a class via hyprctl
close_all() {
    local addrs
    addrs=$(get_addrs "$1")
    for addr in $addrs; do
        hyprctl dispatch closewindow "address:$addr" 2>/dev/null || true
    done
}

# =============================================================================
# CLOSE EXISTING LAYOUT APPS (fresh start)
# =============================================================================

close_all "brave-browser"
close_all "code-insiders"
close_all "spotify"

# Wait for windows to close
sleep 1

# =============================================================================
# FORCE WORKSPACES ONTO EXTERNAL MONITOR
# =============================================================================

hyprctl dispatch moveworkspacetomonitor "1 $EXT" 2>/dev/null
hyprctl dispatch moveworkspacetomonitor "2 $EXT" 2>/dev/null

# Force dwindle to always split right (columns, not rows on ultrawide)
hyprctl keyword dwindle:force_split 2 2>/dev/null
hyprctl keyword dwindle:split_width_multiplier 1.5 2>/dev/null

# Focus workspace 1 on external monitor
hyprctl dispatch focusmonitor "$EXT" 2>/dev/null
hyprctl dispatch workspace 1 2>/dev/null
sleep 0.3

# =============================================================================
# COLUMN 1: VS CODE
# =============================================================================

code-insiders &>/dev/null &
disown
vscode_addr=$(wait_for_window "code-insiders" "") || true
if [[ -n "$vscode_addr" ]]; then
    hyprctl dispatch movetoworkspacesilent "1,address:$vscode_addr" 2>/dev/null
    hyprctl dispatch focuswindow "address:$vscode_addr" 2>/dev/null
fi
sleep 1

# =============================================================================
# COLUMN 2: ChatGPT (splits: [VSCode | ChatGPT])
# =============================================================================

known_brave=""
brave --new-window "https://chatgpt.com" &>/dev/null &
disown
chat_addr=$(wait_for_window "brave-browser" "$known_brave") || true
known_brave="$known_brave $chat_addr"
sleep 1

# =============================================================================
# COLUMN 3: Calendar
# Focus ChatGPT → Calendar splits its half → [VSCode | ChatGPT | Calendar]
# =============================================================================

[[ -n "$chat_addr" ]] && hyprctl dispatch focuswindow "address:$chat_addr" 2>/dev/null
sleep 0.3
brave --new-window "https://calendar.google.com" &>/dev/null &
disown
cal_addr=$(wait_for_window "brave-browser" "$known_brave") || true
known_brave="$known_brave $cal_addr"
sleep 1

# =============================================================================
# COLUMN 4: Gmail
# Focus Calendar → Gmail splits its half → [VSCode | ChatGPT | Calendar | Gmail]
# =============================================================================

[[ -n "$cal_addr" ]] && hyprctl dispatch focuswindow "address:$cal_addr" 2>/dev/null
sleep 0.3
brave --new-window "https://mail.google.com" &>/dev/null &
disown
gmail_addr=$(wait_for_window "brave-browser" "$known_brave") || true
sleep 1

# =============================================================================
# SPOTIFY on workspace 2 (external)
# =============================================================================

spotify &>/dev/null &
disown
spot_addr=$(wait_for_window "spotify" "") || true
[[ -n "$spot_addr" ]] && hyprctl dispatch movetoworkspacesilent "2,address:$spot_addr" 2>/dev/null

# =============================================================================
# CLEANUP
# =============================================================================

hyprctl keyword dwindle:split_width_multiplier 1.0 2>/dev/null
hyprctl dispatch workspace 1 2>/dev/null

notify-send -i display "Docked Layout" "VSCode | ChatGPT | Calendar | Gmail\nSpotify → workspace 2" -t 3000 2>/dev/null || true
