#!/usr/bin/env bash
# Obsidian note launcher for Waybar
# Shows root-level notes to continue, or creates a new one

VAULT="NOTES"
VAULT_PATH="$HOME/GoogleDrive/NOTES"

# Collect root-level .md files (names only, no extension)
NOTES=$(find "$VAULT_PATH" -maxdepth 1 -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort)

# Build menu: "New Note" first, then existing notes
MENU=$(printf "+ New Note\n%s" "$NOTES")

CHOICE=$(echo "$MENU" | rofi -dmenu -i -p "Obsidian" -theme-str 'window {width: 320px;}')

[ -z "$CHOICE" ] && exit 0

if [ "$CHOICE" = "+ New Note" ]; then
    TITLE=$(rofi -dmenu -p "Title" -l 0 -theme-str 'window {width: 320px;}')
    [ -z "$TITLE" ] && exit 0
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TITLE")
    xdg-open "obsidian://new?vault=${VAULT}&name=${ENCODED}" &
else
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$CHOICE")
    xdg-open "obsidian://open?vault=${VAULT}&file=${ENCODED}" &
fi
