local function command(keys, cmd, opts)
    hl.bind(keys, hl.dsp.exec_cmd(cmd), opts)
end

-- Lid handling.
command("switch:on:Lid Switch", "~/.config/hypr/lid-handler.sh close", { locked = true })
command("switch:off:Lid Switch", "~/.config/hypr/lid-handler.sh open", { locked = true })

-- Session and applications.
command("SUPER + Return", "foot")
command("SUPER + D", "rofi -show drun")
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + Escape", hl.dsp.exit())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
command("SUPER + S", "bash ~/.config/scripts/screenshot.sh")
command("SUPER + C", "cliphist list | rofi -dmenu | cliphist decode | wl-copy")
command("SUPER + B", "~/.config/scripts/waybar-restart.sh")
command("SUPER + W", [[awww img "$(find ~/Pictures/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | shuf -n 1)" --transition-type fade --transition-duration 2]])

command("XF86MonBrightnessUp", "brightnessctl set +5%", { repeating = true })
command("XF86MonBrightnessDown", "brightnessctl set 5%-", { repeating = true })

-- Workspace navigation.
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

-- Focus and window movement.
for key, direction in pairs({
    left = "l",
    right = "r",
    up = "u",
    down = "d",
    H = "l",
    L = "r",
    K = "u",
    J = "d",
}) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

command("SUPER + E", "thunar")
command("SUPER + V", "code-insiders")
command("SUPER + P", "nwg-displays")
command("SUPER + N", "~/.config/waybar/wifi-menu.sh")
command("SUPER + SHIFT + N", "~/.config/waybar/wifi-menu.sh --toggle")
command("SUPER + T", "~/.config/scripts/reverse-tether.sh")
command("SUPER + G", "systemctl --user restart rclone-googledrive.service")
command("SUPER + SHIFT + D", "~/.config/scripts/dock-layout.sh")

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("SUPER + SHIFT + comma", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + period", hl.dsp.window.move({ monitor = "r" }))
hl.bind("SUPER + comma", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + period", hl.dsp.focus({ monitor = "r" }))
hl.bind("SUPER + SHIFT + bracketleft", hl.dsp.window.move({ monitor = "-1" }))
hl.bind("SUPER + SHIFT + bracketright", hl.dsp.window.move({ monitor = "+1" }))

-- Resize mode.
hl.bind("SUPER + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local resize = {
        right = { 40, 0 },
        left = { -40, 0 },
        up = { 0, -40 },
        down = { 0, 40 },
        l = { 40, 0 },
        h = { -40, 0 },
        k = { 0, -40 },
        j = { 0, 40 },
    }

    for key, delta in pairs(resize) do
        hl.bind(key, hl.dsp.window.resize({
            x = delta[1],
            y = delta[2],
            relative = true,
        }), { repeating = true })
    end

    for key, delta in pairs({
        right = { 10, 0 },
        left = { -10, 0 },
        up = { 0, -10 },
        down = { 0, 10 },
    }) do
        hl.bind("SHIFT + " .. key, hl.dsp.window.resize({
            x = delta[1],
            y = delta[2],
            relative = true,
        }), { repeating = true })
    end

    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)
