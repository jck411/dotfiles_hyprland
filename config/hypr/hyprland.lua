-- Hyprland entry point. Keep responsibilities in focused modules.
require("host")
require("monitors")

-- Fallback for unknown or newly connected outputs.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

require("options")
require("rules")
require("quake")
require("autostart")
require("binds")
