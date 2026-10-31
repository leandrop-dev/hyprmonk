-- hyprpm plugins: hymission (the overview, Super+Tab in binds.lua), with its
-- defaults. hyprpm loads it at every start, once it has any. Building it needs
-- Hyprland running, so an install from outside can only leave it for later:
-- until its state file exists, each login opens a terminal to do it, which
-- asks for the password.

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    -- if, not [: a leading [...] is read as window rules
    hl.exec_cmd('if test -e "/var/cache/hyprpm/$USER/state.toml"; then hyprpm reload; '
        .. 'else kitty --hold "$HOME/.local/bin/hyprmonk" install plugins; fi')
end)
