-- hyprpm plugins: hymission (the overview, Super+Tab in binds.lua), with its
-- defaults. Install it once with `install.sh plugins`; until it is loaded,
-- its bind does nothing. hyprpm loads it at every start, once it has any:
-- before that step, its state file is missing and hyprpm would only say the
-- plugins need updating.

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    -- test, not [: a leading [...] is read as window rules
    hl.exec_cmd('test -e "/var/cache/hyprpm/$USER/state.toml" && hyprpm reload')
end)
