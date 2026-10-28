-- Game mode, switched from the quick actions (Super+A): no animations, blur
-- or shadows, and variable refresh for fullscreen windows, while
-- ~/.local/state/hyprmonk/game-mode reads "on". (The shell also holds back
-- notification pop-ups meanwhile.)
-- The shell writes that file and reloads the config, so a reload keeps game
-- mode as it was.

local file = io.open(os.getenv("HOME") .. "/.local/state/hyprmonk/game-mode")
if not file then return end
local on = file:read("l") == "on"
file:close()

if on then
    hl.config({
        animations = { enabled = false },
        decoration = {
            blur   = { enabled = false },
            shadow = { enabled = false },
        },
        -- 2: only while a window is fullscreen (a game), where it helps;
        -- on the desktop it can flicker. Needs a screen and driver that
        -- support it over the cable in use.
        misc = { vrr = 2 },
    })
end
