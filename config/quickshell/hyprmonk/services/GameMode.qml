// Game mode: Hyprland drops animations, blur and shadows (hypr/gamemode.lua).
// The switch is a file in the state directory that the config reads on every
// load, so turning it on or off writes the file and reloads Hyprland's config.
//
// IPC: qs -c hyprmonk ipc call gamemode toggle  (prints the new state)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool on: false

    function toggle(): void {
        file.setText(on ? "off\n" : "on\n");
        on = !on;
        Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
    }

    IpcHandler {
        target: "gamemode"

        function toggle(): bool {
            root.toggle();
            return root.on;
        }
    }

    FileView {
        id: file
        path: Theme.stateDir + "/game-mode"
        blockWrites: true
        printErrors: false
        onLoaded: root.on = text().trim() === "on"
        onLoadFailed: root.on = false
    }
}
