// Colours, type and sizes for every surface.
//
// The look: dark translucent cards with a faint rim, monospace type, and one
// accent taken from the wallpaper. The tone (background and text) is fixed;
// the accent comes from matugen's colors.json in the state directory, and the
// default below applies until matugen has run.
//
// matugen's post_hook calls `qs -c hyprmonk ipc call theme reload`: a file
// watch alone misses the first run, when the file does not exist yet.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hyprmonk"

    // Tone
    readonly property color background: "#1e1a17"
    readonly property color foreground: "#f2ede6"
    readonly property real cardOpacity: 0.6
    readonly property color card: Qt.alpha(background, cardOpacity)
    readonly property color rim: fg(0.08)
    readonly property color accent: colors.accent
    readonly property color positive: "#3dff3d"
    readonly property color warning: "#ff5f56"

    // Foreground at an opacity: secondary text, hover fills, idle items.
    function fg(alpha: real): color {
        return Qt.alpha(foreground, alpha);
    }

    // Type
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int bodyFontSize: 12
    readonly property int smallFontSize: 11

    // Bar
    readonly property int barHeight: 38       // one card
    readonly property int barGap: 5           // above and below the cards
    readonly property int barMargin: 15       // from the screen's sides
    readonly property int cardRadius: 12
    readonly property int cardPadding: 6
    readonly property int moduleRadius: 8
    readonly property real hoverOpacity: 0.08
    readonly property real dimOpacity: 0.45

    // Panels and pop-ups
    readonly property int panelRadius: 16
    readonly property int notificationWidth: 500         // pop-ups and the centre
    readonly property int notificationCenterHeight: 600  // most the centre grows to

    // OSD: as wide as the max with a bar, else fitted to its row
    readonly property int osdMaxWidth: 360
    readonly property int osdMinWidth: 160

    IpcHandler {
        target: "theme"

        function reload(): void {
            file.reload();
        }
    }

    FileView {
        id: file
        path: theme.stateDir + "/theme/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: colors
            property string accent: "#ef8608"
        }
    }
}
