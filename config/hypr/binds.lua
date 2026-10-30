-- Keybindings. Every bind has a description, filed under the section set
-- last: the key guide (Super+K) reads them from Hyprland as "Section: text"
-- and lists them by section. Binds sharing a description share a row.

local mod = "SUPER"
local section = ""
-- install.sh puts it here; the session's PATH does not include it.
local hyprmonk = os.getenv("HOME") .. "/.local/bin/hyprmonk"

local function bind(keys, action, description, opts)
    opts = opts or {}
    opts.description = section .. ": " .. description
    hl.bind(keys, action, opts)
end

section = "Apps"
bind(mod .. " + Return", hl.dsp.exec_cmd(terminal),    "Terminal")
bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager), "File manager")
bind(mod .. " + Space",  hl.dsp.exec_cmd(launcher),    "App launcher")
bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle clipboard"), "Clipboard history")

section = "Windows"
bind(mod .. " + Q",         hl.dsp.window.close(),                            "Close window")
bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }),       "Toggle floating")
bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize")
bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
bind(mod .. " + P",         hl.dsp.window.pin(),                              "Pin to every workspace")
bind(mod .. " + J",         hl.dsp.layout("togglesplit"),                     "Toggle split direction")

local directions = { { "left", "l" }, { "right", "r" }, { "up", "u" }, { "down", "d" } }
for _, d in ipairs(directions) do
    bind(mod .. " + " .. d[1], hl.dsp.focus({ direction = d[2] }), "Focus a neighbour")
end
for _, d in ipairs(directions) do
    bind(mod .. " + SHIFT + " .. d[1], hl.dsp.window.move({ direction = d[2] }), "Move window")
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

section = "Workspaces"
for i = 1, 10 do
    bind(mod .. " + " .. tostring(i % 10), hl.dsp.focus({ workspace = i }), "Go to workspace 1-10")
end
for i = 1, 10 do
    bind(mod .. " + SHIFT + " .. tostring(i % 10), hl.dsp.window.move({ workspace = i }), "Move window to workspace 1-10")
end
bind(mod .. " + S",          hl.dsp.workspace.toggle_special("scratch"),          "Scratchpad")
bind(mod .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:scratch" }), "Move window to scratchpad")
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }),                 "Next workspace")
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }),                 "Previous workspace")

section = "Shell"
-- Overview (hymission); a no-op until the plugin is loaded.
bind(mod .. " + Tab", function()
    if hl.plugin.hymission then hl.plugin.hymission.toggle() end
end, "Overview")
bind(mod .. " + A",         hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle quickactions"), "Quick actions")
bind(mod .. " + K",         hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle keyguide"),     "Key guide")
bind(mod .. " + W",         hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle wallpapers"),   "Wallpapers")
bind(mod .. " + N",         hl.dsp.exec_cmd("qs -c hyprmonk ipc call notifications toggle"),         "Notification centre")
bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("qs -c hyprmonk ipc call notifications clear"),          "Clear notifications")
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("qs -c hyprmonk ipc call recorder toggle"),              "Screen recording")

-- Screenshots: Print enters a mode whose keys pick what to take (the shell
-- shows them on a card while it lasts); each one leaves the mode. Shift
-- copies instead of saving. The key guide lists the mode, not its keys.
section = "Screenshots"
bind("Print", hl.dsp.submap("screenshot"), "Screenshot (then R, W or S; Shift copies)")
hl.define_submap("screenshot", function()
    local function shot(key, args, description)
        hl.bind(key, function()
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(hl.dsp.exec_cmd(hyprmonk .. " screenshot " .. args))
        end, { description = description })
    end
    shot("R",         "region",        "Region")
    shot("W",         "window",        "Window")
    shot("S",         "screen",        "Screen")
    shot("SHIFT + R", "region --copy", "Region to clipboard")
    shot("SHIFT + W", "window --copy", "Window to clipboard")
    shot("SHIFT + S", "screen --copy", "Screen to clipboard")
    hl.bind("Escape", hl.dsp.submap("reset"), { description = "Cancel" })
    hl.bind("Print",  hl.dsp.submap("reset"), { description = "Cancel" })
end)

section = "Session"
bind(mod .. " + ALT + L",   hl.dsp.exec_cmd("qs -c hyprmonk ipc call lock lock"),             "Lock")
bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle power"), "Power menu")

-- Caps and Num Lock keep working; the OSD reads the new state. Not shortcuts
-- (non-consuming), so the key guide leaves them out. On release: a lock turns
-- on when its key goes down but off only when it comes up (XKB), so a read on
-- the press would still find it on. Ignoring modifiers, as the lock is one by
-- then and a release bind without it never fires.
local locks = { non_consuming = true, locked = true, release = true, ignore_mods = true }
bind("Caps_Lock", hl.dsp.exec_cmd("qs -c hyprmonk ipc call osd locks"), "Caps Lock", locks)
bind("Num_Lock",  hl.dsp.exec_cmd("qs -c hyprmonk ipc call osd locks"), "Num Lock",  locks)

-- Media keys work on the lock screen too.
section = "Media"
local media = { locked = true }
local held  = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up",   held)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "Volume down", held)
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "Mute",        media)
bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   "Mute microphone", media)
bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause",     media)
bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause",     media)
bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       "Next track",     media)
bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   "Previous track", media)
