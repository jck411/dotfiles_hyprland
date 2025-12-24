#!/usr/bin/env bash
# MCP Server Pool Toggle for Waybar
# Click: Start/stop MCP servers
# Right-click: Open settings GUI

MCP_SCRIPT="/home/human/REPOS/Backend_FastAPI/scripts/start_mcp_servers.py"
MCP_CONFIG="/home/human/REPOS/Backend_FastAPI/data/mcp_servers.json"
PID_FILE="$HOME/.cache/mcp_pool.pid"
LOG_FILE="$HOME/.cache/mcp_pool.log"

is_running() {
    # Check if any MCP servers are listening on their ports (works regardless of how started)
    ss -tln 2>/dev/null | grep -qE ":(9001|9002|9003|9004|9005) "
}

count_servers() {
    local count=0
    for port in 9001 9002 9003 9004 9005 9006 9007 9008 9009 9010; do
        if ss -tln 2>/dev/null | grep -q ":$port "; then
            ((count++))
        fi
    done
    echo "$count"
}

get_status() {
    if is_running; then
        local count=$(count_servers)
        echo "{\"text\": \" \", \"tooltip\": \"MCP Servers Running ($count)\\nClick: toggle | Right-click: settings\", \"class\": \"running\"}"
    else
        echo '{"text": " ", "tooltip": "MCP Servers Stopped\nClick: start | Right-click: settings", "class": "stopped"}'
    fi
}

start_pool() {
    if is_running; then
        notify-send -i dialog-information "MCP Servers" "Already running" -t 2000
        return
    fi

    cd /home/human/REPOS/Backend_FastAPI || exit 1
    nohup .venv/bin/python "$MCP_SCRIPT" --config "$MCP_CONFIG" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    if is_running; then
        local count=$(count_servers)
        notify-send -i dialog-information "MCP Servers" "Started ($count servers)" -t 2000
    else
        notify-send -i dialog-error "MCP Servers" "Failed to start" -t 3000
    fi
}

stop_pool() {
    if ! is_running; then
        notify-send -i dialog-information "MCP Servers" "Not running" -t 2000
        return
    fi

    # Kill processes on MCP ports
    for port in 9001 9002 9003 9004 9005 9006 9007 9008 9009 9010; do
        fuser -k $port/tcp 2>/dev/null
    done
    
    # Also try killing the pool script
    pkill -f "start_mcp_servers" 2>/dev/null
    
    rm -f "$PID_FILE"
    sleep 0.5
    
    if ! is_running; then
        notify-send -i dialog-information "MCP Servers" "Stopped" -t 2000
    else
        notify-send -i dialog-warning "MCP Servers" "May still be running" -t 3000
    fi
}

toggle() {
    if is_running; then
        stop_pool
    else
        start_pool
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    start) start_pool ;;
    stop) stop_pool ;;
    settings) brave --app="http://localhost:5173/mcp.html" --disable-extensions --no-first-run & ;;
    status|*) get_status ;;
esac
