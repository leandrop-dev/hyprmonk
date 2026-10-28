// Opens hymission's overview (the same as Super+Tab). The dispatch is a Lua
// expression that evaluates to the plugin's function, which Hyprland calls.
import Quickshell.Hyprland

Module {
    icon: "\u{F0F8D}"
    interactive: true
    onClicked: Hyprland.dispatch("hl.plugin.hymission.toggle")
}
