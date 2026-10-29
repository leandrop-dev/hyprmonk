-- Gaps, borders, blur and animations. Colours come from `theme` (hyprland.lua).

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = theme.accent,
            inactive_border = theme.inactive,
        },
        layout = "dwindle",
    },
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 3,
            color        = theme.shadow,
        },
        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- A shell restarted while locked locks again.
        allow_session_lock_restore = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},  {0.32, 1} } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("snappy",       { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global",     enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",     enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, spring = "snappy" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.1,  spring = "snappy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "almostLinear", style = "popin 87%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3.03, bezier = "almostLinear" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
