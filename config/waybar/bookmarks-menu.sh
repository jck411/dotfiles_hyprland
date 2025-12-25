#!/usr/bin/env bash
# Bookmarks menu for Waybar
# Opens a rofi menu with web app bookmarks

MENU_OPTIONS="ChatGPT
Gemini
Google
Dev Server
Calendar
Gmail
GitHub Repos"

CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Bookmarks" -theme-str 'window {width: 200px;}')

case "$CHOICE" in
    "ChatGPT")
        brave --app=https://chat.openai.com --profile-directory=ChatGPT --disable-extensions --disable-background-networking --disable-sync --no-first-run &
        ;;
    "Gemini")
        brave --app=https://gemini.google.com/app --profile-directory=Gemini --disable-extensions --disable-background-networking --disable-sync --no-first-run &
        ;;
    "Google")
        brave --app=https://www.google.com/ --disable-extensions --no-first-run &
        ;;
    "Dev Server")
        brave --app=http://localhost:5173/ --disable-extensions --no-first-run &
        ;;
    "Calendar")
        brave --app="https://calendar.google.com/calendar/u/0/r?pli=1" --disable-extensions --no-first-run &
        ;;
    "Gmail")
        brave --app="https://mail.google.com/mail/u/0/#inbox" --disable-extensions --no-first-run &
        ;;
    "GitHub Repos")
        brave --app="https://github.com/jck411?tab=repositories" --disable-extensions --no-first-run &
        ;;
esac
