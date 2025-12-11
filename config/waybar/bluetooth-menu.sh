#!/bin/bash
# Bluetooth device manager using rofi and bluetoothctl

# Get bluetooth power status
get_power_status() {
    bluetoothctl show | grep "Powered:" | awk '{print $2}'
}

# Toggle bluetooth power
toggle_power() {
    status=$(get_power_status)
    if [[ "$status" == "yes" ]]; then
        bluetoothctl power off
        notify-send "Bluetooth" "Disabled" -i bluetooth-disabled
    else
        bluetoothctl power on
        notify-send "Bluetooth" "Enabled" -i bluetooth-active
    fi
}

# Get paired devices
get_paired_devices() {
    bluetoothctl devices Paired 2>/dev/null | cut -d' ' -f2-
}

# Get connected devices
get_connected_devices() {
    bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f2
}

# Check if device is connected
is_connected() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

# Get device name from MAC
get_device_name() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep "Name:" | cut -d: -f2- | sed 's/^ *//'
}

# Get device icon based on type
get_device_icon() {
    local mac="$1"
    local icon_type=$(bluetoothctl info "$mac" 2>/dev/null | grep "Icon:" | awk '{print $2}')
    
    case "$icon_type" in
        audio-headphones|audio-headset) echo "󰋋" ;;
        audio-card|audio-speakers) echo "󰓃" ;;
        input-keyboard) echo "󰌌" ;;
        input-mouse) echo "󰍽" ;;
        input-gaming) echo "󰊗" ;;
        phone) echo "󰏲" ;;
        computer) echo "󰍹" ;;
        *) echo "󰂯" ;;
    esac
}

# Get battery level if available
get_battery() {
    local mac="$1"
    local battery=$(bluetoothctl info "$mac" 2>/dev/null | grep "Battery Percentage" | grep -oP '\d+')
    [[ -n "$battery" ]] && echo " ${battery}%"
}

# Connect to device
connect_device() {
    local mac="$1"
    local name=$(get_device_name "$mac")
    
    notify-send "Bluetooth" "Connecting to $name..." -i bluetooth-active
    
    if bluetoothctl connect "$mac" 2>/dev/null | grep -q "successful"; then
        notify-send "Bluetooth" "Connected to $name" -i bluetooth-active
    else
        notify-send "Bluetooth" "Failed to connect to $name" -i bluetooth-disabled
    fi
}

# Disconnect device
disconnect_device() {
    local mac="$1"
    local name=$(get_device_name "$mac")
    
    if bluetoothctl disconnect "$mac" 2>/dev/null | grep -q "successful"; then
        notify-send "Bluetooth" "Disconnected from $name" -i bluetooth-disabled
    else
        notify-send "Bluetooth" "Failed to disconnect from $name" -i dialog-error
    fi
}

# Remove/forget a device
remove_device() {
    local mac="$1"
    local name=$(get_device_name "$mac")
    
    # Confirm removal
    confirm=$(echo -e "Yes\nNo" | rofi -dmenu -i -p "Forget $name?" -theme-str 'window {width: 250px;}')
    
    if [[ "$confirm" == "Yes" ]]; then
        bluetoothctl remove "$mac" && \
            notify-send "Bluetooth" "Removed $name" -i bluetooth-disabled || \
            notify-send "Bluetooth" "Failed to remove $name" -i dialog-error
    fi
}

# Scan for new devices
scan_devices() {
    notify-send "Bluetooth" "Scanning for devices..." -i bluetooth-active
    
    # Start scanning in background
    bluetoothctl --timeout 10 scan on &>/dev/null &
    scan_pid=$!
    
    # Wait a bit then show discovered devices
    sleep 5
    
    # Get newly discovered devices (not paired)
    paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')
    all_devices=$(bluetoothctl devices 2>/dev/null)
    
    options=""
    while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        
        # Skip if already paired
        if echo "$paired_macs" | grep -qx "$mac"; then
            continue
        fi
        
        [[ -z "$name" || "$name" == "$mac" ]] && continue
        options+="$mac $name\n"
    done <<< "$all_devices"
    
    kill $scan_pid 2>/dev/null
    bluetoothctl scan off &>/dev/null
    
    if [[ -z "$options" ]]; then
        notify-send "Bluetooth" "No new devices found" -i bluetooth-active
        return
    fi
    
    selected=$(echo -e "$options" | rofi -dmenu -i -p "Pair Device" -theme-str 'window {width: 350px;}')
    
    if [[ -n "$selected" ]]; then
        mac=$(echo "$selected" | awk '{print $1}')
        name=$(echo "$selected" | cut -d' ' -f2-)
        
        notify-send "Bluetooth" "Pairing with $name..." -i bluetooth-active
        
        if bluetoothctl pair "$mac" && bluetoothctl trust "$mac"; then
            notify-send "Bluetooth" "Paired with $name" -i bluetooth-active
            connect_device "$mac"
        else
            notify-send "Bluetooth" "Failed to pair with $name" -i bluetooth-disabled
        fi
    fi
}

show_menu() {
    power_status=$(get_power_status)
    
    options=""
    
    # Power toggle
    if [[ "$power_status" == "yes" ]]; then
        options+="󰂲  Disable Bluetooth\n"
        options+="─────────────\n"
        
        # List paired devices
        paired=$(bluetoothctl devices Paired 2>/dev/null)
        
        if [[ -n "$paired" ]]; then
            while read -r line; do
                [[ -z "$line" ]] && continue
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                icon=$(get_device_icon "$mac")
                battery=$(get_battery "$mac")
                
                if is_connected "$mac"; then
                    options+="$icon  $name (connected)$battery\n"
                else
                    options+="$icon  $name\n"
                fi
            done <<< "$paired"
            
            options+="─────────────\n"
        fi
        
        options+="󰂰  Scan for Devices\n"
        options+="󱛅  Remove Device"
    else
        options+="󰂯  Enable Bluetooth"
    fi
    
    selected=$(echo -e "$options" | rofi -dmenu -i -p "Bluetooth" -theme-str 'window {width: 320px;}')
    
    [[ -z "$selected" ]] && exit 0
    
    case "$selected" in
        *"Disable Bluetooth"*) toggle_power ;;
        *"Enable Bluetooth"*) toggle_power ;;
        *"Scan for Devices"*) scan_devices ;;
        *"Remove Device"*)
            # Show device list for removal
            paired=$(bluetoothctl devices Paired 2>/dev/null)
            device_list=""
            while read -r line; do
                [[ -z "$line" ]] && continue
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                device_list+="$mac $name\n"
            done <<< "$paired"
            
            if [[ -n "$device_list" ]]; then
                sel=$(echo -e "$device_list" | rofi -dmenu -i -p "Remove" -theme-str 'window {width: 300px;}')
                if [[ -n "$sel" ]]; then
                    mac=$(echo "$sel" | awk '{print $1}')
                    remove_device "$mac"
                fi
            fi
            ;;
        *"(connected)"*)
            # Already connected - offer disconnect
            name=$(echo "$selected" | sed 's/^[^ ]* *//' | sed 's/ (connected).*//')
            mac=$(bluetoothctl devices Paired | grep "$name" | awk '{print $2}')
            
            action=$(echo -e "Disconnect\nCancel" | rofi -dmenu -i -p "$name" -theme-str 'window {width: 200px;}')
            [[ "$action" == "Disconnect" ]] && disconnect_device "$mac"
            ;;
        *)
            # Connect to device
            name=$(echo "$selected" | sed 's/^[^ ]* *//')
            mac=$(bluetoothctl devices Paired | grep "$name" | awk '{print $2}')
            [[ -n "$mac" ]] && connect_device "$mac"
            ;;
    esac
}

show_menu
