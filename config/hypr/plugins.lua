-- hyprpm plugins: hyprglass (liquid glass) and hymission (overview).
-- Install them once with `install.sh plugins`. Each block only applies while
-- its plugin is loaded, so the config also works without them; Hyprland
-- re-reads the config after every plugin load, so they apply once
-- `hyprpm reload` has run.

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload")
end)

if hl.plugin.hyprglass then
    hl.plugin.hyprglass.config({
        default_theme  = "dark",
        default_preset = "clear",
    })
end
