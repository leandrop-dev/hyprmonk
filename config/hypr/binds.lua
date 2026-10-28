-- Keybindings. Every bind has a description: the key guide panel lists them.

local mod = "SUPER"

local function bind(keys, action, description, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, action, opts)
end

-- Apps
bind(mod .. " + Return", hl.dsp.exec_cmd(terminal),    "Terminal")
bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager), "File manager")
bind(mod .. " + Space",  hl.dsp.exec_cmd(launcher),    "App launcher")

-- Windows
bind(mod .. " + Q",         hl.dsp.window.close(),                            "Close window")
bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }),       "Toggle floating")
bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize")
bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
bind(mod .. " + P",         hl.dsp.window.pin(),                              "Pin to every workspace")
bind(mod .. " + J",         hl.dsp.layout("togglesplit"),                     "Toggle split direction")

for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
    bind(mod .. " + " .. key,             hl.dsp.focus({ direction = dir }),       "Focus " .. key)
    bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir }), "Move window " .. key)
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

-- Workspaces
for i = 1, 10 do
    local key = tostring(i % 10)
    bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       "Workspace " .. i)
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end
bind(mod .. " + S",          hl.dsp.workspace.toggle_special("scratch"),          "Scratchpad")
bind(mod .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:scratch" }), "Move window to scratchpad")
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }),                 "Next workspace")
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }),                 "Previous workspace")

-- Overview (hymission); a no-op until the plugin is loaded.
bind(mod .. " + Tab", function()
    if hl.plugin.hymission then hl.plugin.hymission.toggle() end
end, "Overview")

-- Notifications
bind(mod .. " + N",         hl.dsp.exec_cmd("qs -c hyprmonk ipc call notifications toggle"), "Notification centre")
bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("qs -c hyprmonk ipc call notifications clear"),  "Clear notifications")

-- Quick actions
bind(mod .. " + K", hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle quickactions"), "Quick actions")

-- Caps and Num Lock keep working; the OSD reads the new state.
local locks = { non_consuming = true, locked = true }
bind("Caps_Lock", hl.dsp.exec_cmd("qs -c hyprmonk ipc call osd locks"), "Caps Lock", locks)
bind("Num_Lock",  hl.dsp.exec_cmd("qs -c hyprmonk ipc call osd locks"), "Num Lock",  locks)

-- Session
bind(mod .. " + ALT + L", hl.dsp.exec_cmd("qs -c hyprmonk ipc call lock lock"), "Lock")
bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("qs -c hyprmonk ipc call overlays toggle power"), "Power menu")

-- Media keys work on the lock screen too.
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
