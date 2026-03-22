#!/bin/bash
# dock-layout.sh — 4-column docked layout for ultrawide (external monitor only)
#
# Kills existing layout apps, then launches fresh on workspace 1 (external):
#   Calendar | VSCode | ChatGPT | Spotify(top) + Thunar(bottom)
#
# Only runs when docked (external monitor detected). Bound to SUPER+SHIFT+D.
# Uses dwindle binary splits to build the column layout.

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

get_addrs() {
    hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    if '$1' in c.get('class', ''):
        print(c['address'])
" 2>/dev/null
}

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
close_all "brave-calendar"
close_all "code-insiders"
close_all "spotify"
close_all "thunar"

sleep 1

# =============================================================================
# FORCE WORKSPACE ONTO EXTERNAL MONITOR
# =============================================================================

hyprctl dispatch moveworkspacetomonitor "1 $EXT" 2>/dev/null

# Dwindle: split right/bottom; multiplier 1.5 ensures horizontal splits at 50%
# width (2560/1440=1.78 > 1.5) but vertical at 25% width (1280/1440=0.89 < 1.5)
hyprctl keyword dwindle:force_split 2 2>/dev/null
hyprctl keyword dwindle:split_width_multiplier 1.5 2>/dev/null

hyprctl dispatch focusmonitor "$EXT" 2>/dev/null
hyprctl dispatch workspace 1 2>/dev/null
sleep 0.3

# =============================================================================
# STEP 1: Calendar (Brave PWA — fills workspace)
# =============================================================================

brave --profile-directory=Default --app=https://calendar.google.com/calendar/u/0/r &>/dev/null &
disown
cal_addr=$(wait_for_window "brave-calendar" "") || true
sleep 1

# =============================================================================
# STEP 2: ChatGPT (splits Calendar → [Calendar | ChatGPT])
# =============================================================================

brave --new-window "https://chatgpt.com" &>/dev/null &
disown
chat_addr=$(wait_for_window "brave-browser" "") || true
sleep 1

# =============================================================================
# STEP 3: VSCode (focus Calendar → splits it → [[Calendar | VSCode] | ChatGPT])
# =============================================================================

[[ -n "$cal_addr" ]] && hyprctl dispatch focuswindow "address:$cal_addr" 2>/dev/null
sleep 0.3
code-insiders &>/dev/null &
disown
vscode_addr=$(wait_for_window "code-insiders" "") || true
sleep 1

# =============================================================================
# STEP 4: Spotify (focus ChatGPT → splits it →
#   [[Calendar | VSCode] | [ChatGPT | Spotify]])
# =============================================================================

[[ -n "$chat_addr" ]] && hyprctl dispatch focuswindow "address:$chat_addr" 2>/dev/null
sleep 0.3
spotify &>/dev/null &
disown
spot_addr=$(wait_for_window "spotify" "") || true
sleep 1

# =============================================================================
# STEP 5: Thunar (focus Spotify → vertical split since column is taller than
#   wide → [[Calendar | VSCode] | [ChatGPT | [Spotify / Thunar]]])
# =============================================================================

[[ -n "$spot_addr" ]] && hyprctl dispatch focuswindow "address:$spot_addr" 2>/dev/null
sleep 0.3
thunar &>/dev/null &
disown
wait_for_window "thunar" "" >/dev/null || true
sleep 0.5

# =============================================================================
# CLEANUP
# =============================================================================

hyprctl keyword dwindle:split_width_multiplier 1.0 2>/dev/null
hyprctl dispatch workspace 1 2>/dev/null

notify-send -i display "Docked Layout" "Calendar | VSCode | ChatGPT | Spotify/Thunar" -t 3000 2>/dev/null || true
