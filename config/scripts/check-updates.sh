#!/bin/bash

set -e

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SUCCESS_FILE="$STATE_HOME/machine-update/last-success"
STATUS_FILE="$STATE_HOME/machine-update/status"
UPDATE_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/update-system.sh"
UPDATE_INTERVAL_SECONDS=604800

# Do not start a large update from a noninteractive shell.
if [ ! -t 0 ]; then
    exit 0
fi

LAST_SUCCESS="$(cat "$SUCCESS_FILE" 2>/dev/null || true)"
CURRENT_TIME="$(date +%s)"
UPDATE_STATE="$(sed -n 's/^state=//p' "$STATUS_FILE" 2>/dev/null || true)"

case "$UPDATE_STATE" in
    failed)
        UPDATE_LOG="$(sed -n 's/^log=//p' "$STATUS_FILE" 2>/dev/null || true)"
        echo
        echo -e "\033[1;31mThe last system update failed; automatic retry is paused.\033[0m"
        echo "Fix the reported error, then run: $UPDATE_SCRIPT"
        [ -n "$UPDATE_LOG" ] && echo "Log: $UPDATE_LOG"
        exit 0
        ;;
    running)
        exit 0
        ;;
esac

if [[ "$LAST_SUCCESS" =~ ^[0-9]+$ ]] &&
   [ $((CURRENT_TIME - LAST_SUCCESS)) -le "$UPDATE_INTERVAL_SECONDS" ]; then
    exit 0
fi

echo
echo -e "\033[1;33mSystem update is due; starting it noninteractively.\033[0m"
exec "$UPDATE_SCRIPT"
