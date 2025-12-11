#!/bin/bash

TIMESTAMP_FILE="$HOME/.config/last_update_timestamp"
UPDATE_SCRIPT="$HOME/.config/scripts/update-system.sh"

# Only run if attached to a terminal
if [ ! -t 0 ]; then
    exit 0
fi

if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_UPDATE=$(cat "$TIMESTAMP_FILE")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_UPDATE))
    # 7 days = 604800 seconds
    if [ $DIFF -gt 604800 ]; then
        echo
        echo -e "\033[1;33mWARNING: It has been over a week since your last system update.\033[0m"
        read -p "Would you like to run the update and cleanup now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$UPDATE_SCRIPT"
        fi
    fi
else
    # No timestamp found
    echo
    echo -e "\033[1;33mNo system update timestamp found.\033[0m"
    read -p "Would you like to run the initial system update and cleanup now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$UPDATE_SCRIPT"
    fi
fi
