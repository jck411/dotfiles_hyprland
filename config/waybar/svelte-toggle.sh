#!/usr/bin/env bash
# AI Stack toggle for Waybar (matches start.sh options 2+3)
# Click: Toggle MCP Servers + Frontend together
# Right-click: Open frontend in browser

PROJECT_DIR="/home/human/REPOS/Backend_FastAPI"
FRONTEND_DIR="$PROJECT_DIR/frontend"
STATE_FILE="$HOME/.cache/ai-stack.state"

# Load MCP port range from single source of truth
source "$PROJECT_DIR/data/mcp_ports.conf"
MCP_PORTS=($(seq $MCP_PORT_START $MCP_PORT_END))

# Cache ss output for efficiency (called once per invocation)
_ss_cache=""
get_listening_ports() {
    [[ -z "$_ss_cache" ]] && _ss_cache=$(ss -tln 2>/dev/null)
    echo "$_ss_cache"
}

is_frontend_running() {
    # Check if port 5173 is listening (more reliable than process matching)
    get_listening_ports | grep -q ":5173 "
}

is_mcp_running() {
    get_listening_ports | grep -qE ":90(0[1-9]|1[0-5]) "
}

count_mcp_servers() {
    local count=0 ports
    ports=$(get_listening_ports)
    for port in "${MCP_PORTS[@]}"; do
        echo "$ports" | grep -q ":$port " && ((count++))
    done
    echo "$count"
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
        echo '{"text": " ", "tooltip": "AI Stack Starting...\nPlease wait", "class": "starting"}'
        return
    fi

    local frontend_on=false mcp_on=false count=0

    is_frontend_running && frontend_on=true
    is_mcp_running && { mcp_on=true; count=$(count_mcp_servers); }

    if $frontend_on && $mcp_on; then
        echo "{\"text\": \" \", \"tooltip\": \"AI Stack Running\\nFrontend: localhost:5173\\nMCP Servers: $count active\\nClick: stop | Right-click: open\", \"class\": \"running\"}"
    elif $frontend_on || $mcp_on; then
        local f_status="off" m_status="off"
        $frontend_on && f_status="on"
        $mcp_on && m_status="on ($count)"
        echo "{\"text\": \" \", \"tooltip\": \"AI Stack Partial\\nFrontend: $f_status\\nMCP: $m_status\\nClick: toggle | Right-click: open\", \"class\": \"partial\"}"
    else
        echo '{"text": " ", "tooltip": "AI Stack Stopped\nClick to start", "class": "stopped"}'
    fi
}

do_start() {
    # This runs in background - does the actual work
    cd "$PROJECT_DIR" || exit 1
    local started=""

    # Start MCP Servers first (option 2)
    if ! is_mcp_running; then
        for port in "${MCP_PORTS[@]}"; do
            uv run python scripts/kill_port.py "$port" 2>/dev/null
        done
        uv run python scripts/start_mcp_servers.py &
        started="MCP"
        sleep 3
    fi

    # Start Frontend (option 3)
    if ! is_frontend_running; then
        uv run python scripts/kill_port.py 5173 2>/dev/null
        cd "$FRONTEND_DIR" && npm run dev &
        [[ -n "$started" ]] && started="$started + Frontend" || started="Frontend"
        sleep 3
    fi

    # Clear starting state
    clear_state
    _ss_cache=""

    # Final notification
    local count=$(count_mcp_servers)
    notify-send -i dialog-information "AI Stack" "Ready!\nMCP: $count servers\nFrontend: localhost:5173" -t 3000
}

start_stack() {
    if is_frontend_running && is_mcp_running; then
        notify-send -i dialog-information "AI Stack" "Already running" -t 2000
        return
    fi

    # Set starting state immediately
    set_state "starting"
    
    # Show starting notification
    notify-send -i dialog-information "AI Stack" "Starting services..." -t 2000

    # Run the actual start in background so waybar doesn't block
    (do_start) > /dev/null 2>&1 &
}

stop_stack() {
    if ! is_frontend_running && ! is_mcp_running; then
        notify-send -i dialog-information "AI Stack" "Not running" -t 2000
        return
    fi

    clear_state
    local stopped=""

    # Stop Frontend
    if is_frontend_running; then
        # Kill by port (most reliable)
        fuser -k 5173/tcp 2>/dev/null
        pkill -f "node.*vite" 2>/dev/null
        stopped="Frontend"
    fi

    # Stop MCP Servers
    if is_mcp_running; then
        pkill -f "start_mcp_servers.py" 2>/dev/null
        pkill -f "mcp_registry" 2>/dev/null
        for port in "${MCP_PORTS[@]}"; do
            fuser -k "$port/tcp" 2>/dev/null
        done
        [[ -n "$stopped" ]] && stopped="$stopped + MCP" || stopped="MCP"
    fi

    notify-send -i dialog-information "AI Stack" "Stopped ($stopped)" -t 2000
}

toggle() {
    if is_starting; then
        notify-send -i dialog-warning "AI Stack" "Already starting, please wait..." -t 2000
        return
    fi

    if is_frontend_running || is_mcp_running; then
        stop_stack
    else
        start_stack
    fi
}

open_browser() {
    if is_frontend_running; then
        brave --app="http://localhost:5173" --remote-debugging-port=9222 --force-dark-mode &
    else
        notify-send -i dialog-warning "AI Stack" "Frontend not running\nClick to start first" -t 2000
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    start) start_stack ;;
    stop) stop_stack ;;
    open) open_browser ;;
    status|*) get_status ;;
esac
