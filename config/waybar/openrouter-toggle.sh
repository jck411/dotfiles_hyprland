#!/usr/bin/env bash
# Backend Toggle for Waybar (matches start.sh option 1)
# Click: Toggle backend on/off

BACKEND_DIR="/home/human/REPOS/Backend_FastAPI"
HEALTH_URL="http://localhost:8000/health"
STATE_FILE="$HOME/.cache/backend.state"

is_process_running() {
    pgrep -f "uvicorn.*backend\.app" > /dev/null 2>&1
}

is_healthy() {
    curl -sf "$HEALTH_URL" > /dev/null 2>&1
}

is_starting() {
    [[ -f "$STATE_FILE" ]] && [[ $(cat "$STATE_FILE" 2>/dev/null) == "starting" ]]
}

set_state() {
    echo "$1" > "$STATE_FILE"
}

clear_state() {
    rm -f "$STATE_FILE"
}

get_status() {
    # Check if we're in a starting state
    if is_starting; then
        echo '{"text": " ", "tooltip": "Backend API Starting...\nPlease wait", "class": "starting"}'
        return
    fi

    if is_process_running; then
        if is_healthy; then
            echo '{"text": " ", "tooltip": "Backend API Running (port 8000)\nHealth: OK\nClick to stop", "class": "running"}'
        else
            echo '{"text": " ", "tooltip": "Backend API Running\nHealth: waiting...\nClick to stop", "class": "partial"}'
        fi
    else
        echo '{"text": " ", "tooltip": "Backend API Stopped\nClick to start", "class": "stopped"}'
    fi
}

do_start() {
    # This runs in background - does the actual work
    cd "$BACKEND_DIR" || exit 1

    # Clean port (same as start.sh)
    uv run python scripts/kill_port.py 8000 2>/dev/null

    # Start backend (same as start.sh)
    uv run uvicorn backend.app:create_app \
        --factory \
        --host 0.0.0.0 \
        --reload &

    # Wait for health check (up to 15 seconds)
    local max_attempts=15
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if is_healthy; then
            clear_state
            notify-send -i dialog-information "Backend API" "Ready on localhost:8000" -t 2000
            return
        fi
        sleep 1
        ((attempt++))
    done

    # Timed out but process might still be running
    clear_state
    if is_process_running; then
        notify-send -i dialog-warning "Backend API" "Started (health check pending)" -t 3000
    else
        notify-send -i dialog-error "Backend API" "Failed to start" -t 3000
    fi
}

start_backend() {
    if is_process_running; then
        notify-send -i dialog-information "Backend API" "Already running" -t 2000
        return
    fi

    # Set starting state immediately
    set_state "starting"

    # Show starting notification
    notify-send -i dialog-information "Backend API" "Starting..." -t 2000

    # Run the actual start in background so waybar doesn't block
    (do_start) > /dev/null 2>&1 &
}

stop_backend() {
    if ! is_process_running; then
        notify-send -i dialog-information "Backend API" "Not running" -t 2000
        return
    fi

    clear_state

    # Same cleanup as start.sh
    pkill -f "uvicorn backend.app:create_app" 2>/dev/null
    sleep 0.5

    if ! is_process_running; then
        notify-send -i dialog-information "Backend API" "Stopped" -t 2000
    else
        pkill -9 -f "uvicorn.*backend" 2>/dev/null
        notify-send -i dialog-warning "Backend API" "Force stopped" -t 2000
    fi
}

toggle() {
    if is_starting; then
        notify-send -i dialog-warning "Backend API" "Already starting, please wait..." -t 2000
        return
    fi

    if is_process_running; then
        stop_backend
    else
        start_backend
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    start) start_backend ;;
    stop) stop_backend ;;
    status|*) get_status ;;
esac
