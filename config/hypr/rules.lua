-- Window and layer rules.

-- XWayland drag-and-drop ghosts must not take focus.
hl.window_rule({
    name  = "xwayland-drag-ghosts",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- The shell's surfaces are named hyprmonk-*: blur what is behind them, unless
-- the tone says not to (Settings > Tone).
if theme.cardBlur ~= false then
    hl.layer_rule({ name = "hyprmonk-blur", match = { namespace = "^hyprmonk-.*" }, blur = true, ignore_alpha = 0.01 })
end
-- The cards that open and close by the shell's own animation
-- (services/Motion.qml) come and go without Hyprland's fade on top, a second
-- animation; the others (the notification popups, polkit, the bar and
-- the dock) keep it, on the same curve. The screenshot mode's card also has
-- to leave at once: the picture is taken right after.
hl.layer_rule({ name = "hyprmonk-cards", no_anim = true,
    match = { namespace = "^hyprmonk-(overlay|launcher|power|quickactions|settings|wallpapers|keyguide|osd|screenshot)$" } })

-- satty (screenshots, to annotate before saving): a floating card, which the
-- Floating layout leaves floating when it ends.
hl.window_rule({
    name  = "satty",
    match = { class = "^com\\.gabm\\.satty$" },
    float = true,
    tag   = "-hyprmonk-floating",
    size  = "(monitor_w*0.7) (monitor_h*0.7)",
    center = true,
})

-- Games (docs/zendo-games.md): Windows games under Proton are steam_app_<id>
-- (steam_app_default when umu does not know them), games inside gamescope
-- are gamescope; checked from Zendo on 2026-11-06. A tile would give them a size some keep as their own
-- setting (Unity's), so they float, centred at the size they ask for, and
-- go full screen when they ask to. The Floating layout leaves them out
-- (floating.lua), and they stay floating when it ends.
hl.window_rule({
    name   = "games",
    match  = { class = "^(steam_app_.*|gamescope)$" },
    float  = true,
    center = true,
    tag    = "-hyprmonk-floating",
})

-- Zendo, the game launcher, floats as a window of its own, as do its sign-in
-- windows (all of class zendo).
hl.window_rule({
    name   = "zendo",
    match  = { class = "^zendo$" },
    float  = true,
    center = true,
    tag    = "-hyprmonk-floating",
})
