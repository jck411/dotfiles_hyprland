#!/bin/bash

set -e

SAVE_DIR="$HOME/Downloads"
OUTPUT_FILE="$SAVE_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

mkdir -p "$SAVE_DIR"

grim -g "$(slurp)" - | swappy -f - -o "$OUTPUT_FILE"

if [[ -s "$OUTPUT_FILE" ]]; then
    wl-copy --type image/png < "$OUTPUT_FILE"
fi