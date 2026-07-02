#!/bin/bash
# Bluetooth device menu for Waybar.

set -e

THEME="waybar"
PROMPT="Bluetooth"
MAC_RE='([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'

bt() {
    bluetoothctl "$@" 2>/dev/null
}

notify_bt() {
    local message="$1"
    local icon="${2:-bluetooth-active}"
    notify-send "Bluetooth" "$message" -i "$icon" 2>/dev/null || true
}

menu() {
    printf "%b" "$1" | rofi -dmenu -i -p "$PROMPT" -theme "$THEME" || true
}

has_controller() {
    bt show >/dev/null
}

powered() {
    [[ "$(bt show | awk '/Powered:/ {print $2; exit}')" == "yes" ]]
}

paired_devices() {
    bt devices Paired | awk -v re="^Device ${MAC_RE} " '$0 ~ re'
}

device_info() {
    bt info "$1"
}

device_prop() {
    local mac="$1"
    local key="$2"

    device_info "$mac" | awk -F: -v key="$key" '
        $1 ~ "^[[:space:]]*" key "$" {
            sub(/^[[:space:]]+/, "", $2)
            print $2
            exit
        }
    '
}

device_connected() {
    device_info "$1" | grep -q "Connected: yes"
}

device_icon() {
    case "$(device_prop "$1" Icon)" in
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

device_battery() {
    device_info "$1" |
        sed -n 's/.*(\([0-9][0-9]*\)).*/ \1%/p' |
        head -1
}

mac_from_choice() {
    grep -oE "$MAC_RE" <<< "$1" | tail -1
}

name_from_line() {
    local line="$1"
    local mac="$2"

    printf "%s" "${line#Device $mac }"
}

device_row() {
    local line="$1"
    local mac name connected=""

    mac=$(awk '{print $2}' <<< "$line")
    name=$(name_from_line "$line" "$mac")
    [[ -n "$name" ]] || name="$(device_prop "$mac" Name)"
    [[ -n "$name" ]] || name="$mac"

    device_connected "$mac" && connected=" (connected)"
    printf "%s  %s%s%s  [%s]\n" \
        "$(device_icon "$mac")" "$name" "$connected" "$(device_battery "$mac")" "$mac"
}

device_name() {
    local mac="$1"
    local name

    name="$(device_prop "$mac" Name)"
    [[ -n "$name" ]] && printf "%s" "$name" || printf "%s" "$mac"
}

open_blueman() {
    if ! command -v blueman-manager >/dev/null 2>&1; then
        notify_bt "Blueman is not installed" "dialog-error"
        return
    fi

    if has_controller && ! powered && ! bt power on >/dev/null; then
        notify_bt "Failed to enable Bluetooth" "dialog-error"
        return
    fi

    notify_bt "Opening device pairing"
    blueman-manager >/dev/null 2>&1 &
}

toggle_power() {
    if powered; then
        bt power off >/dev/null && notify_bt "Disabled" "bluetooth-disabled" ||
            notify_bt "Failed to disable Bluetooth" "dialog-error"
    else
        bt power on >/dev/null && notify_bt "Enabled" ||
            notify_bt "Failed to enable Bluetooth" "dialog-error"
    fi
}

connect_device() {
    local mac="$1"
    local name

    name="$(device_name "$mac")"
    notify_bt "Connecting to $name..."
    if bt connect "$mac" | grep -qi "successful"; then
        notify_bt "Connected to $name"
    else
        notify_bt "Failed to connect to $name" "bluetooth-disabled"
    fi
}

disconnect_device() {
    local mac="$1"
    local name

    name="$(device_name "$mac")"
    bt disconnect "$mac" >/dev/null && notify_bt "Disconnected from $name" "bluetooth-disabled" ||
        notify_bt "Failed to disconnect from $name" "dialog-error"
}

remove_device() {
    local mac="$1"
    local name confirm

    name="$(device_name "$mac")"
    confirm=$(printf "Yes\nNo\n" | rofi -dmenu -i -p "Forget $name?" -theme "$THEME" || true)
    [[ "$confirm" == "Yes" ]] || return

    bt remove "$mac" >/dev/null && notify_bt "Removed $name" "bluetooth-disabled" ||
        notify_bt "Failed to remove $name" "dialog-error"
}

device_rows() {
    local line

    while read -r line; do
        [[ -n "$line" ]] && device_row "$line"
    done <<< "$(paired_devices)"
    return 0
}

show_remove_menu() {
    local selected mac rows

    rows="$(device_rows)"
    if [[ -z "$rows" ]]; then
        notify_bt "No paired devices" "bluetooth-disabled"
        return
    fi

    selected=$(printf "%s\n" "$rows" | rofi -dmenu -i -p "Remove" -theme "$THEME" || true)
    mac=$(mac_from_choice "$selected")
    [[ -n "$mac" ]] && remove_device "$mac"
}

show_no_controller_menu() {
    case "$(menu "󰂯  No Bluetooth controller\n󰂰  Open Blueman\n󰑓  Retry\n")" in
        *"Open Blueman"*) open_blueman ;;
        *"Retry"*) show_menu ;;
    esac
}

show_menu() {
    local selected mac options rows

    if ! has_controller; then
        show_no_controller_menu
        return
    fi

    if ! powered; then
        case "$(menu "󰂯  Enable Bluetooth\n󰂰  Pair / Connect New Device\n")" in
            *"Enable Bluetooth"*) toggle_power ;;
            *"Pair / Connect New Device"*) open_blueman ;;
        esac
        return
    fi

    rows="$(device_rows)"
    options="󰂰  Pair / Connect New Device\n${rows:+$rows\n}󱛅  Remove Device\n󰂲  Disable Bluetooth\n"
    selected=$(menu "$options")
    [[ -n "$selected" ]] || return

    case "$selected" in
        *"Pair / Connect New Device"*) open_blueman ;;
        *"Remove Device"*) show_remove_menu ;;
        *"Disable Bluetooth"*) toggle_power ;;
        *)
            mac=$(mac_from_choice "$selected")
            [[ -n "$mac" ]] || return
            if device_connected "$mac"; then
                selected=$(printf "Disconnect\nCancel\n" | rofi -dmenu -i -p "$(device_name "$mac")" -theme "$THEME" || true)
                [[ "$selected" == "Disconnect" ]] && disconnect_device "$mac"
            else
                connect_device "$mac"
            fi
            ;;
    esac
}

show_menu
