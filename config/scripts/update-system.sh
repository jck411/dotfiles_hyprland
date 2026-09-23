#!/bin/bash

# Entry point for the machine's unattended updater.

set -e

UPDATER="$HOME/REPOS/machine-thinkpad-p16s/scripts/system-update.sh"

if [ ! -x "$UPDATER" ]; then
    echo "Error: machine updater not found or not executable: $UPDATER" >&2
    exit 1
fi

exec "$UPDATER"
