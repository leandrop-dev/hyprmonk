-- Settings > Windows' Floating layout, for anyone used to Windows: every
-- window floats, resizes from its borders and snaps to the screen's edges and
-- to other windows. Off until settings.lua (written by the shell) calls
-- hyprmonk_floating(true); loaded before it.
--
-- The rule floats windows as they open and marks them with the tag
-- hyprmonk-floating; hyprmonk_floating_switch, which the shell calls when the
-- choice changes, also floats the windows already open (marking them too),
-- and on the way out tiles back only the marked ones, so windows other rules
-- float (satty, which drops the mark) stay as they are. Dialogs (modal) are
-- left out of the mark.

-- Most apps ask for no size and would float over the whole screen: they open
-- at 60% by 70% of it, centred, and keep the size given them afterwards.
-- Apps still may not maximise themselves (rules.lua): kitty asks as it opens.
local width, height = 0.6, 0.7

local float_all = hl.window_rule({
    name   = "hyprmonk-floating",
    match  = { class = ".*", modal = false },
    float  = true,
    size   = string.format("(monitor_w*%s) (monitor_h*%s)", width, height),
    center = true,
    persistent_size = true,
    tag    = "+hyprmonk-floating",
})
float_all:set_enabled(false)

-- An app asking to be maximized (its own title bar's button, or as it opens)
-- would fight the tiling layouts; in Floating it is welcome. Hyprland settles
-- this as a window opens, so a window keeps the answer it opened with.
local suppress_maximize = hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Title bars (the hyprbars plugin, `install.sh plugins`), in the tone's
-- colours (theme/tone.lua), with close, maximise and minimise (minimise.lua);
-- a double click also maximises. Apps that draw their own title bar get none.
local maximise = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]
local bars = hl.plugin and hl.plugin.hyprbars

if bars then
    -- Like the shell's cards: the tone's card opacity, blurred unless the tone
    -- says not to.
    hl.config({ plugin = { hyprbars = {
        enabled           = false,
        bar_height        = 34,
        bar_color         = theme.surface,
        bar_blur          = theme.cardBlur ~= false,
        col               = { text = theme.text },
        bar_text_font     = "JetBrainsMono Nerd Font",
        bar_text_size     = 12,
        bar_text_align    = "left",
        bar_padding       = 12,
        bar_button_padding = 8,
        bar_precedence_over_border = true,
        on_double_click   = maximise,
    } } })
    -- The first button sits at the far right. hyprbars draws an icon at 0.62
    -- of its button's size, snapped to whole pixels: an odd size keeps the
    -- odd-width icons on the circle's centre (24 left them half a pixel off).
    -- On hover (our fork's hover_color, install.sh): close turns red as on
    -- Windows, the others take a wash of the text.
    local wash = theme.text:gsub("^rgb%((%x+)%)$", "rgba(%133)")
    bars.add_button({ bg_color = "rgba(00000000)", fg_color = theme.text, hover_color = "rgb(c42b1c)",
                      size = 25, icon = "\u{F05AD}", action = "hyprctl dispatch 'hl.dsp.window.close()'" })
    bars.add_button({ bg_color = "rgba(00000000)", fg_color = theme.text, hover_color = wash,
                      size = 25, icon = "\u{F05AF}", action = maximise })
    bars.add_button({ bg_color = "rgba(00000000)", fg_color = theme.text, hover_color = wash,
                      size = 25, icon = "\u{F05B0}", action = "hyprctl eval 'hyprmonk_minimise()'" })

    hl.window_rule({
        name  = "hyprbars-own-title-bar",
        match = { class = "^(org\\.gnome\\..*|net\\.nokyan\\.Resources|zen|vesktop|steam|dev\\.zed\\.Zed"
                       .. "|org\\.mozilla\\.Thunderbird|com\\.gabm\\.satty|localsend.*)$" },
        ["hyprbars:no_bar"] = true,
    })
end

-- Apps drawing their own title bar (Zen, GNOME apps) take their buttons from
-- GTK's button layout: in Floating, maximise, and minimise once the
-- minimize-requests plugin passes it on (minimise.lua); elsewhere only close.
-- Set once the whole config has run, since settings.lua turns Floating on
-- after this file.
local floating = false

local function loaded(name)
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == name then return true end
    end
    return false
end

hl.on("config.reloaded", function()
    local layout = "appmenu:close"
    if floating then
        layout = loaded("minimize-requests") and "appmenu:minimize,maximize,close" or "appmenu:maximize,close"
    end
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout '" .. layout .. "'")
end)

function hyprmonk_floating(on)
    floating = on
    float_all:set_enabled(on)
    suppress_maximize:set_enabled(not on)
    hl.config({ general = { resize_on_border = on, snap = { enabled = on } } })
    if bars then hl.config({ plugin = { hyprbars = { enabled = on } } }) end
end

local function marked(window)
    for _, tag in ipairs(window.tags) do
        if tag:gsub("%*$", "") == "hyprmonk-floating" then return true end
    end
    return false
end

function hyprmonk_floating_switch(on)
    for _, window in ipairs(hl.get_windows()) do
        local target = "address:" .. window.address
        if on and not window.floating and window.fullscreen == 0 then
            hl.dispatch(hl.dsp.window.tag({ tag = "+hyprmonk-floating", window = target }))
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
            local monitor = window.monitor
            hl.dispatch(hl.dsp.window.resize({ window = target, x = math.floor(monitor.width * width),
                                               y = math.floor(monitor.height * height) }))
            hl.dispatch(hl.dsp.window.center({ window = target }))
        elseif not on and window.floating and marked(window) then
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = target }))
            hl.dispatch(hl.dsp.window.tag({ tag = "-hyprmonk-floating", window = target }))
        end
    end
    hyprmonk_floating(on)
end
