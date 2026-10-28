-- hyprpm plugins: hymission (the overview, Super+Tab in binds.lua), with its
-- defaults. Install it once with `install.sh plugins`; until it is loaded,
-- its bind does nothing. hyprpm loads it at every start.

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload")
end)
