#!/bin/bash
# WiFi network selector using rofi and nmcli
# Launched from waybar network click or SUPER+N

# Get current connection
get_current() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep wireless | cut -d: -f1
}

# Get WiFi status
get_wifi_status() {
    nmcli -t -f WIFI g 2>/dev/null | head -1
}

# Get list of saved network names
get_saved_networks() {
    nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep wireless | cut -d: -f1
}

# Scan and list networks
list_networks() {
    nmcli device wifi rescan 2>/dev/null
    sleep 0.5
    # Return SSID, signal, security — using \t as delimiter to handle spaces in SSIDs
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | grep -v '^:' | sort -t: -k2 -rn | awk -F: '!seen[$1]++' 
}

# Toggle WiFi on/off
toggle_wifi() {
    if [[ "$(get_wifi_status)" == "enabled" ]]; then
        nmcli radio wifi off
        notify-send "WiFi" "Disabled" -i network-wireless-offline
    else
        nmcli radio wifi on
        notify-send "WiFi" "Enabled" -i network-wireless
        sleep 1
        show_menu
    fi
}

# Open captive portal page if detected
check_captive_portal() {
    sleep 2
    local connectivity
    connectivity=$(nmcli -t -f CONNECTIVITY g 2>/dev/null)
    if [[ "$connectivity" == "portal" ]]; then
        notify-send "WiFi" "Captive portal detected — opening browser" -i network-wireless
        xdg-open http://nmcheck.gnome.org/check_network_status.txt 2>/dev/null &
    fi
}

# Connect to a network
connect_network() {
    local ssid="$1"
    local security="$2"

    # Check if we have a saved connection
    if get_saved_networks | grep -qxF "$ssid"; then
        if nmcli connection up "$ssid" 2>&1; then
            notify-send "WiFi" "Connected to $ssid" -i network-wireless
            check_captive_portal &
        else
            notify-send "WiFi" "Failed to connect to $ssid" -i network-wireless-offline
        fi
        return
    fi

    # Open network — connect directly without password
    if [[ -z "$security" || "$security" == "--" || "$security" == "" ]]; then
        if nmcli device wifi connect "$ssid" 2>&1; then
            notify-send "WiFi" "Connected to $ssid" -i network-wireless
            check_captive_portal &
        else
            notify-send "WiFi" "Failed to connect to $ssid" -i network-wireless-offline
        fi
        return
    fi

    # Secured network — prompt for password
    password=$(rofi -dmenu -password -p "Password for $ssid" -theme waybar -theme-str 'listview {lines: 0;}')
    if [[ -n "$password" ]]; then
        nmcli device wifi connect "$ssid" password "$password" 2>&1 && \
            notify-send "WiFi" "Connected to $ssid" -i network-wireless || \
            notify-send "WiFi" "Failed to connect to $ssid" -i network-wireless-offline
    fi
}

# Disconnect current network
disconnect_network() {
    local current
    current=$(get_current)
    if [[ -n "$current" ]]; then
        nmcli connection down "$current"
        notify-send "WiFi" "Disconnected from $current" -i network-wireless-disconnected
    fi
}

# Forget a saved network
forget_network() {
    local saved
    saved=$(get_saved_networks)

    if [[ -z "$saved" ]]; then
        notify-send "WiFi" "No saved networks" -i network-wireless
        return
    fi

    local selected
    selected=$(echo "$saved" | rofi -dmenu -i -p "󱛅 Forget" -theme waybar)

    if [[ -n "$selected" ]]; then
        nmcli connection delete "$selected" && \
            notify-send "WiFi" "Forgot $selected" -i network-wireless || \
            notify-send "WiFi" "Failed to forget $selected" -i dialog-error
    fi
}

# Show connection details
show_info() {
    local current
    current=$(get_current)
    if [[ -z "$current" ]]; then
        notify-send "WiFi" "Not connected" -i network-wireless-disconnected
        return
    fi

    local ip gateway dns signal
    ip=$(nmcli -t -f IP4.ADDRESS device show wlan0 2>/dev/null | head -1 | cut -d: -f2)
    gateway=$(nmcli -t -f IP4.GATEWAY device show wlan0 2>/dev/null | head -1 | cut -d: -f2)
    dns=$(nmcli -t -f IP4.DNS device show wlan0 2>/dev/null | head -1 | cut -d: -f2)
    signal=$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep '^\*' | cut -d: -f2)

    notify-send "WiFi — $current" "Signal: ${signal}%\nIP: $ip\nGateway: $gateway\nDNS: $dns" -i network-wireless
}

# ── Main menu ──────────────────────────────────────────────────

show_menu() {
    local wifi_status current options="" networks saved_list

    wifi_status=$(get_wifi_status)
    current=$(get_current)

    if [[ "$wifi_status" != "enabled" ]]; then
        selected=$(echo "󰤨  Enable WiFi" | rofi -dmenu -i -p "WiFi" -theme waybar)
        [[ "$selected" == *"Enable"* ]] && toggle_wifi
        return
    fi

    # ── Build menu ──
    options="󰤭  Disable WiFi\n"

    if [[ -n "$current" ]]; then
        options+="󰤨  $current (connected)\n"
        options+="  Connection Info\n"
        options+="󰤮  Disconnect\n"
    fi

    # Collect saved network names for marking
    saved_list=$(get_saved_networks)

    # Available networks
    networks=$(list_networks)
    local has_networks=false
    local net_entries=""
    # Store SSID→security mapping for later lookup
    declare -A security_map

    while IFS=: read -r ssid signal security; do
        [[ -z "$ssid" ]] && continue
        [[ "$ssid" == "$current" ]] && continue

        has_networks=true

        # Signal icon
        local icon
        if [[ $signal -ge 75 ]]; then   icon="󰤨"
        elif [[ $signal -ge 50 ]]; then icon="󰤥"
        elif [[ $signal -ge 25 ]]; then icon="󰤢"
        else                            icon="󰤟"
        fi

        # Lock for secured, globe for open
        local lock=""
        if [[ -n "$security" && "$security" != "--" ]]; then
            lock=" 󰌾"
        else
            lock=" 󰖟"
        fi

        # Star if saved
        local saved_mark=""
        if echo "$saved_list" | grep -qxF "$ssid"; then
            saved_mark=" ★"
        fi

        net_entries+="$icon  $ssid${lock}${saved_mark}  ${signal}%\n"
        security_map["$ssid"]="$security"
    done <<< "$networks"

    if [[ "$has_networks" == true ]]; then
        options+="$net_entries"
    fi

    options+="󱛅  Forget Network\n"
    options+="󰑓  Rescan"

    # Show rofi
    selected=$(echo -e "$options" | rofi -dmenu -i -p "  WiFi" -theme waybar)

    [[ -z "$selected" ]] && return

    case "$selected" in
        *"Disable WiFi"*)  toggle_wifi ;;
        *"Enable WiFi"*)   toggle_wifi ;;
        *"Connection Info"*) show_info ;;
        *"Disconnect"*)    disconnect_network ;;
        *"Forget Network"*) forget_network ;;
        *"Rescan"*)        show_menu ;;
        *"(connected)"*)   show_info ;;
        *)
            # Extract SSID: strip leading icon+spaces, then strip trailing markers
            local ssid
            ssid=$(echo "$selected" | sed 's/^[^ ]* *//')         # remove icon
            ssid=$(echo "$ssid" | sed 's/  [0-9]*%$//')           # remove "  75%"
            ssid=$(echo "$ssid" | sed 's/ ★$//')                  # remove saved star
            ssid=$(echo "$ssid" | sed 's/ 󰌾$//')                  # remove lock
            ssid=$(echo "$ssid" | sed 's/ 󰖟$//')                  # remove globe
            ssid=$(echo "$ssid" | sed 's/[[:space:]]*$//')         # trim trailing spaces

            local sec="${security_map[$ssid]}"
            connect_network "$ssid" "$sec"
            ;;
    esac
}

show_menu
