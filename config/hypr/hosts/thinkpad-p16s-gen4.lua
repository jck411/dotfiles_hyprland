-- ThinkPad P16s Gen 4 AMD host profile.
hl.monitor({
    output = "eDP-1",
    mode = "1920x1200@60",
    position = "auto",
    scale = 1,
})

hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("MESA_LOADER_DRIVER_OVERRIDE", "radeonsi")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    cursor = {
        default_monitor = "eDP-1",
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("xrdb -merge ~/.Xresources")
end)
