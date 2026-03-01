#!/usr/bin/env bash
# Bookmarks menu for Waybar
# Opens a rofi menu with web app bookmarks
# CDP port 9222 for Playwright automation
# Extensions (Dark Reader) load normally

CDP_FLAGS="--remote-debugging-port=9222 --force-dark-mode --disable-session-restore"
MENU_OPTIONS="ChatGPT
Gemini
Google
Calendar
Gmail
GitHub Repos
Frontend
Jacks Home
Chat (jackshome)
Calendar (jackshome)
chat-local
calendar-local"

CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Bookmarks" -theme waybar)

case "$CHOICE" in
    "ChatGPT")
        brave --app=https://chat.openai.com $CDP_FLAGS &
        ;;
    "Gemini")
        brave --app=https://gemini.google.com/app $CDP_FLAGS &
        ;;
    "Google")
        brave --app=https://www.google.com/ $CDP_FLAGS &
        ;;
    "Calendar")
        brave --app="https://calendar.google.com/calendar/u/0/r?pli=1" $CDP_FLAGS &
        ;;
    "Gmail")
        brave --app="https://mail.google.com/mail/u/0/#inbox" $CDP_FLAGS &
        ;;
    "GitHub Repos")
        brave --app="https://github.com/jck411?tab=repositories" $CDP_FLAGS &
        ;;
    "Frontend")
        brave --app="https://192.168.1.111:8000/chat/" $CDP_FLAGS &
        ;;
    "Jacks Home")
        brave --app="https://jackshome.com" $CDP_FLAGS &
        ;;
    "Chat (jackshome)")
        brave --app="https://chat.jackshome.com/" $CDP_FLAGS &
        ;;
    "Calendar (jackshome)")
        brave --app="https://calendar.jackshome.com/" $CDP_FLAGS &
        ;;
    "chat-local")
        brave --app="https://192.168.1.111:8000/" $CDP_FLAGS &
        ;;
    "calendar-local")
        brave --app="http://192.168.1.112/" $CDP_FLAGS &
        ;;
esac
