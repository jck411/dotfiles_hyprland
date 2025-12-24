#!/usr/bin/env bash
# Svelte frontend toggle for Waybar
# Click: Toggle frontend on/off

FRONTEND_DIR="/home/human/REPOS/Backend_FastAPI/frontend"
PID_FILE="$HOME/.cache/svelte-frontend.pid"
LOG_FILE="$HOME/.cache/svelte-frontend.log"

is_running() {
    # Check for actual running vite process (works regardless of how it was started)
    pgrep -f "vite.*frontend" > /dev/null 2>&1 || pgrep -f "node.*vite" > /dev/null 2>&1
}

get_status() {
    if is_running; then
        echo '{"text": " ", "tooltip": "Svelte Frontend Running\nClick to stop", "class": "running"}'
    else
        echo '{"text": " ", "tooltip": "Svelte Frontend Stopped\nClick to start", "class": "stopped"}'
    fi
}

start_frontend() {
    if is_running; then
        notify-send -i dialog-information "Svelte Frontend" "Already running" -t 2000
        return
    fi
    
    cd "$FRONTEND_DIR" || exit 1
    nohup npm run dev > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    if is_running; then
        notify-send -i dialog-information "Svelte Frontend" "Started on localhost:5173" -t 2000
    else
        notify-send -i dialog-error "Svelte Frontend" "Failed to start" -t 3000
    fi
}

stop_frontend() {
    if ! is_running; then
        notify-send -i dialog-information "Svelte Frontend" "Not running" -t 2000
        return
    fi
    
    # Kill any vite process in the frontend directory
    pkill -f "node.*frontend.*vite" 2>/dev/null
    pkill -f "vite.*frontend" 2>/dev/null
    
    # Also kill by port if still running
    fuser -k 5173/tcp 2>/dev/null
    
    rm -f "$PID_FILE"
    sleep 0.5
    
    if ! is_running; then
        notify-send -i dialog-information "Svelte Frontend" "Stopped" -t 2000
    else
        notify-send -i dialog-warning "Svelte Frontend" "May still be running" -t 3000
    fi
}

toggle() {
    if is_running; then
        stop_frontend
    else
        start_frontend
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    start) start_frontend ;;
    stop) stop_frontend ;;
    status|*) get_status ;;
esac
