#!/usr/bin/env bash
# Obsidian note launcher for Waybar
# Shows root-level notes to continue, or creates a new one

VAULT="NOTES"
VAULT_PATH="$HOME/GoogleDrive/NOTES"

# Collect root-level .md files (names only, no extension)
NOTES=$(find "$VAULT_PATH" -maxdepth 1 -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort)

# Build menu: "New Note" and "Mousepad" first, then existing notes
MENU=$(echo -e "+ New Note\nMousepad\0icon\x1forg.xfce.mousepad\n$NOTES")

CHOICE=$(echo "$MENU" | rofi -dmenu -i -p "Obsidian" -show-icons -theme waybar)

[ -z "$CHOICE" ] && exit 0

if [ "$CHOICE" = "+ New Note" ]; then
    TITLE=$(rofi -dmenu -p "Title" -l 0 -theme waybar)
    [ -z "$TITLE" ] && exit 0
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TITLE")
    xdg-open "obsidian://new?vault=${VAULT}&name=${ENCODED}" &
elif [ "$CHOICE" = "Mousepad" ]; then
    mousepad &
else
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$CHOICE")
    xdg-open "obsidian://open?vault=${VAULT}&file=${ENCODED}" &
fi
