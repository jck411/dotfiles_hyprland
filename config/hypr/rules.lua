-- Application placement and dialog behavior.
hl.window_rule({
    name = "thunar-workspace",
    match = { class = "^(thunar)$" },
    workspace = "5 silent",
})

hl.window_rule({
    name = "network-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    size = { 600, 700 },
    center = true,
})

hl.window_rule({
    name = "nwg-displays",
    match = { class = "^(nwg-displays)$" },
    float = true,
    size = { 900, 600 },
    center = true,
})

for _, title in ipairs({ "Open File", "Save As", "Preferences" }) do
    hl.window_rule({
        name = "float-" .. title:lower():gsub(" ", "-"),
        match = { title = "^(" .. title .. ")$" },
        float = true,
    })
end

-- Active and inactive opacity.
hl.window_rule({
    name = "foot-opacity",
    match = { class = "^(foot)$" },
    opacity = "0.95 0.85",
})

hl.window_rule({
    name = "thunar-opacity",
    match = { class = "^(thunar)$" },
    opacity = "0.90 0.85",
})

hl.window_rule({
    name = "rofi-opacity",
    match = { class = "^(rofi)$" },
    opacity = "0.90 0.85",
})

for _, class in ipairs({ "brave-browser", "code-insiders", "cursor" }) do
    hl.window_rule({
        name = class .. "-opaque",
        match = { class = "^(" .. class .. ")$" },
        opacity = "1.0 1.0",
    })
end
