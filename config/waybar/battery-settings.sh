#!/bin/bash
# Battery Settings Dialog for Waybar (rofi-based)

BATTERY_PATH="/sys/class/power_supply/BAT0"
START_THRESHOLD="$BATTERY_PATH/charge_control_start_threshold"
END_THRESHOLD="$BATTERY_PATH/charge_control_end_threshold"

get_capacity() { cat "$BATTERY_PATH/capacity" 2>/dev/null || echo "?"; }
get_status() { cat "$BATTERY_PATH/status" 2>/dev/null || echo "Unknown"; }
get_end() { cat "$END_THRESHOLD" 2>/dev/null || echo "100"; }
is_limited() { [[ "$(get_end)" == "80" ]]; }

set_thresholds() {
    local start=$1 end=$2
    local current_end=$(get_end)
    local success=0
    
    # Order matters: when increasing end, set end first; when decreasing, set start first
    if [[ $end -gt $current_end ]]; then
        # Increasing: set end threshold first
        echo "$end" | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null && \
        echo "$start" | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold > /dev/null && \
        success=1
    else
        # Decreasing: set start threshold first
        echo "$start" | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold > /dev/null && \
        echo "$end" | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null && \
        success=1
    fi
    
    if [[ $success -eq 1 ]]; then
        notify-send -i battery "Battery Settings" "Charge limits: ${start}% - ${end}%"
    else
        notify-send -i battery-caution "Battery Settings" "Failed to set limits"
    fi
}

show_dialog() {
    local capacity=$(get_capacity)
    local status=$(get_status)
    
    # Determine which option is active
    if is_limited; then
        opt_limited="● Limit 60-80%"
        opt_full="○ Charge to 100%"
    else
        opt_limited="○ Limit 60-80%"
        opt_full="● Charge to 100%"
    fi
    
    selected=$(printf "%s\n%s" "$opt_limited" "$opt_full" | rofi -dmenu -i \
        -p "Battery: ${capacity}% • ${status}" \
        -theme-str 'window {width: 280px;}')
    
    case "$selected" in
        *"60-80%"*)
            set_thresholds 60 80
            ;;
        *"100%"*)
            set_thresholds 0 100
            ;;
    esac
}

case "$1" in
    --status) is_limited && echo "limited" || echo "full" ;;
    --info)   echo "Battery: $(get_capacity)% ($(get_status)), Limit: $(get_end)%" ;;
    *)        show_dialog ;;
esac
