// Colours and type for every surface. matugen writes colors.json into the
// state directory (config/matugen); until it has run, the defaults below apply.
// matugen's post_hook calls `qs -c hyprmonk ipc call theme reload`: a file
// watch alone misses the first run, when the file does not exist yet.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hyprmonk"

    readonly property color surface: colors.surface
    readonly property color surfaceHigh: colors.surface_container_high
    readonly property color text: colors.on_surface
    readonly property color textDim: colors.on_surface_variant
    readonly property color accent: colors.primary
    readonly property color onAccent: colors.on_primary
    readonly property color warning: colors.error

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int radius: 10

    IpcHandler {
        target: "theme"

        function reload(): void {
            file.reload();
        }
    }

    FileView {
        id: file
        path: stateDir + "/theme/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: colors
            property string surface: "#1e1e2e"
            property string surface_container_high: "#313244"
            property string on_surface: "#cdd6f4"
            property string on_surface_variant: "#a6adc8"
            property string primary: "#89b4fa"
            property string on_primary: "#1e1e2e"
            property string error: "#f38ba8"
        }
    }
}
