#!/bin/bash

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TIMESTAMP_FILE="$CONFIG_HOME/last_update_timestamp"
UPDATE_SCRIPT="$CONFIG_HOME/scripts/update-system.sh"
PACMAN_LOG="/var/log/pacman.log"
UPDATE_INTERVAL_SECONDS=604800

# Only run if attached to a terminal
if [ ! -t 0 ]; then
    exit 0
fi

read_timestamp_file() {
    local timestamp

    if [ ! -f "$TIMESTAMP_FILE" ]; then
        return 1
    fi

    timestamp=$(cat "$TIMESTAMP_FILE" 2>/dev/null)
    if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
        echo "$timestamp"
        return 0
    fi

    return 1
}

latest_pacman_update() {
    local timestamp

    if [ ! -r "$PACMAN_LOG" ]; then
        return 1
    fi

    timestamp=$(awk '
        /\[PACMAN\] Running '\''pacman / {
            if ($0 ~ / -S[^ ]*u/ || ($0 ~ / -S / && $0 ~ / -u /)) {
                latest = substr($0, 2, 24)
            }
        }
        END {
            if (latest != "") {
                print latest
            }
        }
    ' "$PACMAN_LOG")

    if [ -n "$timestamp" ]; then
        date -d "$timestamp" +%s 2>/dev/null
        return $?
    fi

    return 1
}

remember_update() {
    mkdir -p "$(dirname "$TIMESTAMP_FILE")" 2>/dev/null || return 0
    printf '%s\n' "$1" > "$TIMESTAMP_FILE" 2>/dev/null || true
}

last_update_timestamp() {
    local remembered=0
    local pacman_update=0

    remembered=$(read_timestamp_file || echo 0)
    pacman_update=$(latest_pacman_update || echo 0)

    if [ "$pacman_update" -gt "$remembered" ]; then
        remember_update "$pacman_update"
        echo "$pacman_update"
    elif [ "$remembered" -gt 0 ]; then
        echo "$remembered"
    else
        return 1
    fi
}

LAST_UPDATE=$(last_update_timestamp || true)
CURRENT_TIME=$(date +%s)

if [ -n "$LAST_UPDATE" ]; then
    DIFF=$((CURRENT_TIME - LAST_UPDATE))

    if [ "$DIFF" -gt "$UPDATE_INTERVAL_SECONDS" ]; then
        echo
        echo -e "\033[1;33mWARNING: It has been over a week since your last system update.\033[0m"
        read -p "Would you like to run the update and cleanup now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$UPDATE_SCRIPT"
        fi
    fi
else
    echo
    echo -e "\033[1;33mNo system update timestamp found.\033[0m"
    read -p "Would you like to run the initial system update and cleanup now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$UPDATE_SCRIPT"
    fi
fi
