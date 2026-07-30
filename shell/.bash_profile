#
# ~/.bash_profile
#

# Select Hyprland's current Lua config explicitly during SDDM login.
export HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.lua"

[[ -f ~/.bashrc ]] && . ~/.bashrc

. "$HOME/.local/bin/env"
