-- Quake terminal rules. The keybinds remain disabled until the project is installed.
hl.window_rule({
    name = "quake-terminal",
    match = { class = "^(foot-quake)$" },
    float = true,
    size = { 500, 500 },
    move = { 6, 44 },
    pin = true,
    border_size = 0,
    animation = "slide top",
})
