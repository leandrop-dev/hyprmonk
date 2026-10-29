-- hyprmonk: Hyprland entry point. Each part lives in its own file next to this one.
-- Wiki: https://wiki.hypr.land/Configuring/Start/

-- Generated files (matugen colours) and per-machine overrides live outside the
-- repo, at fixed paths that matugen and kitty use too.
local home  = os.getenv("HOME")
local state = home .. "/.local/state/hyprmonk"
local function load_optional(path)
    local chunk = loadfile(path)
    if chunk then chunk() end
end

theme = {
    accent   = "rgba(89b4faee)",
    inactive = "rgba(45475aaa)",
    shadow   = "rgba(11111bee)",
}
load_optional(state .. "/theme/colors.lua")
-- The Appearance tone's own accent, if it has one (written by the shell).
load_optional(state .. "/theme/tone.lua")

terminal    = "kitty"
fileManager = "nautilus"
launcher    = "qs -c hyprmonk ipc call overlays toggle launcher"

hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@75", position = "0x0", scale = 1 })
-- Anything else plugged in later gets a sensible default to the right.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

require("look")
require("input")
require("binds")
require("rules")
require("plugins")
require("gamemode")

-- No autostart here: the shell and other daemons are systemd user units,
-- started by uwsm with graphical-session.target (see systemd/user/).

-- Machine-specific additions, never part of the repo.
load_optional(home .. "/.config/hyprmonk/local.lua")
