#!/usr/bin/env bash
# OpenRouter Backend Toggle for Waybar
# Click: Toggle backend on/off

BACKEND_DIR="/home/human/REPOS/Backend_FastAPI"
BACKEND_PORT=8000
LOG_FILE="$BACKEND_DIR/logs/backend.log"

is_running() {
    pgrep -f "uvicorn.*backend" > /dev/null 2>&1
}

get_status() {
    if is_running; then
        echo '{"text": " ", "tooltip": "Backend API Running (port 8000)\nClick to stop", "class": "running"}'
    else
        echo '{"text": " ", "tooltip": "Backend API Stopped\nClick to start", "class": "stopped"}'
    fi
}

start_backend() {
    cd "$BACKEND_DIR" || exit 1
    mkdir -p logs
    
    # Kill any process on port 8000 first
    uv run python scripts/kill_port.py 8000 2>/dev/null
    
    nohup uv run uvicorn backend.app:create_app \
        --factory \
        --host 0.0.0.0 \
        --port $BACKEND_PORT \
        >> "$LOG_FILE" 2>&1 &
    
    sleep 2
    if is_running; then
        notify-send -i dialog-information "Backend API" "Started on port $BACKEND_PORT" -t 2000
    else
        notify-send -i dialog-error "Backend API" "Failed to start" -t 3000
    fi
}

stop_backend() {
    pkill -f "uvicorn.*backend"
    sleep 1
    
    if ! is_running; then
        notify-send -i dialog-information "Backend API" "Stopped" -t 2000
    else
        pkill -9 -f "uvicorn.*backend"
        notify-send -i dialog-warning "Backend API" "Force stopped" -t 2000
    fi
}

toggle() {
    if is_running; then
        stop_backend
    else
        start_backend
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    start) [[ ! is_running ]] && start_backend ;;
    stop) is_running && stop_backend ;;
    status|*) get_status ;;
esac
