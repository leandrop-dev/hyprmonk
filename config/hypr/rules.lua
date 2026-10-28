-- Window and layer rules.

-- Apps asking to be maximized would fight the tiling layout.
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland drag-and-drop ghosts must not take focus.
hl.window_rule({
    name  = "xwayland-drag-ghosts",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- The shell's surfaces are named hyprmonk-*: blur what is behind them.
hl.layer_rule({ name = "hyprmonk-blur", match = { namespace = "^hyprmonk-.*" }, blur = true, ignore_alpha = 0.01 })
-- The screenshot mode's card leaves at once, not fading: the picture is
-- taken right after.
hl.layer_rule({ name = "hyprmonk-screenshot", match = { namespace = "^hyprmonk-screenshot$" }, no_anim = true })

-- satty (screenshots, to annotate before saving): a floating card.
hl.window_rule({
    name  = "satty",
    match = { class = "^com\\.gabm\\.satty$" },
    float = true,
    size  = "(monitor_w*0.7) (monitor_h*0.7)",
    center = true,
})
