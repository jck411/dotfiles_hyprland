#!/bin/bash
# WiFi network selector using rofi and nmcli

# Get current connection
get_current() {
    nmcli -t -f NAME,TYPE connection show --active | grep wireless | cut -d: -f1
}

# Get WiFi status
get_wifi_status() {
    nmcli -t -f WIFI g | head -1
}

# Scan and list networks
list_networks() {
    # Trigger a rescan
    nmcli device wifi rescan 2>/dev/null
    sleep 0.5
    
    # List networks: SSID, signal strength, security
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | grep -v '^--' | sort -t: -k2 -rn | uniq
}

# Toggle WiFi on/off
toggle_wifi() {
    status=$(get_wifi_status)
    if [[ "$status" == "enabled" ]]; then
        nmcli radio wifi off
        notify-send "WiFi" "Disabled" -i network-wireless-offline
    else
        nmcli radio wifi on
        notify-send "WiFi" "Enabled" -i network-wireless
    fi
}

# Connect to a network
connect_network() {
    local ssid="$1"
    
    # Check if we have a saved connection
    if nmcli -t -f NAME connection show | grep -qx "$ssid"; then
        nmcli connection up "$ssid" && \
            notify-send "WiFi" "Connected to $ssid" -i network-wireless || \
            notify-send "WiFi" "Failed to connect to $ssid" -i network-wireless-offline
    else
        # Need password - use rofi to get it
        password=$(rofi -dmenu -password -p "Password for $ssid" -theme-str 'window {width: 350px;} listview {lines: 0;}')
        if [[ -n "$password" ]]; then
            nmcli device wifi connect "$ssid" password "$password" && \
                notify-send "WiFi" "Connected to $ssid" -i network-wireless || \
                notify-send "WiFi" "Failed to connect to $ssid" -i network-wireless-offline
        fi
    fi
}

# Disconnect current network
disconnect_network() {
    current=$(get_current)
    if [[ -n "$current" ]]; then
        nmcli connection down "$current"
        notify-send "WiFi" "Disconnected from $current" -i network-wireless-disconnected
    fi
}

# Forget a network
forget_network() {
    # List saved networks
    saved=$(nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d: -f1)
    
    if [[ -z "$saved" ]]; then
        notify-send "WiFi" "No saved networks" -i network-wireless
        return
    fi
    
    selected=$(echo "$saved" | rofi -dmenu -i -p "Forget Network" -theme-str 'window {width: 300px;}')
    
    if [[ -n "$selected" ]]; then
        nmcli connection delete "$selected" && \
            notify-send "WiFi" "Forgot $selected" -i network-wireless || \
            notify-send "WiFi" "Failed to forget $selected" -i dialog-error
    fi
}

show_menu() {
    wifi_status=$(get_wifi_status)
    current=$(get_current)
    
    # Build menu
    options=""
    
    # Toggle option
    if [[ "$wifi_status" == "enabled" ]]; then
        options+="󰤭  Disable WiFi\n"
        options+="─────────────\n"
        
        # Current connection
        if [[ -n "$current" ]]; then
            options+="󰤨  $current (connected)\n"
            options+="󰤮  Disconnect\n"
            options+="─────────────\n"
        fi
        
        # Available networks
        networks=$(list_networks)
        while IFS=: read -r ssid signal security; do
            [[ -z "$ssid" ]] && continue
            [[ "$ssid" == "$current" ]] && continue
            
            # Signal icon
            if [[ $signal -ge 75 ]]; then
                icon="󰤨"
            elif [[ $signal -ge 50 ]]; then
                icon="󰤥"
            elif [[ $signal -ge 25 ]]; then
                icon="󰤢"
            else
                icon="󰤟"
            fi
            
            # Lock icon for secured networks
            if [[ -n "$security" && "$security" != "--" ]]; then
                lock="󰌾"
            else
                lock=""
            fi
            
            options+="$icon  $ssid $lock ${signal}%\n"
        done <<< "$networks"
        
        options+="─────────────\n"
        options+="󱛅  Forget Network\n"
        options+="󰑓  Rescan"
    else
        options+="󰤨  Enable WiFi"
    fi
    
    selected=$(echo -e "$options" | rofi -dmenu -i -p "WiFi" -theme-str 'window {width: 320px;}')
    
    [[ -z "$selected" ]] && exit 0
    
    case "$selected" in
        *"Disable WiFi"*) toggle_wifi ;;
        *"Enable WiFi"*) toggle_wifi ;;
        *"Disconnect"*) disconnect_network ;;
        *"Forget Network"*) forget_network ;;
        *"Rescan"*) show_menu ;;
        *"(connected)"*) ;; # Already connected, do nothing
        *)
            # Extract SSID (remove icon, lock, and signal)
            ssid=$(echo "$selected" | sed 's/^[^ ]* *//' | sed 's/ 󰌾.*$//' | sed 's/ [0-9]*%$//')
            connect_network "$ssid"
            ;;
    esac
}

show_menu
