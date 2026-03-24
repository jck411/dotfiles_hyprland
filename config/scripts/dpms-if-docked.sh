#!/bin/bash
# Turn off displays via DPMS.
# Called by hypridle — gating logic (dock state, screensaver enabled) is handled
# by apply-power-settings.sh which only adds the hypridle listener when appropriate.
hyprctl dispatch dpms off
