// Colours, type and sizes for every surface.
//
// The look: dark translucent cards with a faint rim, monospace type, and one
// accent taken from the wallpaper. The tone (background and text) is one of
// `tones`; the accent comes from matugen's colors.json in the state
// directory, and the defaults below apply until matugen has run.
//
// matugen's post_hook calls `qs -c hyprmonk ipc call theme reload`: a file
// watch alone misses the first run, when the file does not exist yet.
//
// IPC: qs -c hyprmonk ipc call theme tone NAME  (black, slate, espresso,
//      light, mist, ivory or wallpaper)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hyprmonk"

    // Tones: the background, the text and how opaque cards are. One is in
    // use (quick actions > Appearance, kept in appearance.json); "wallpaper"
    // takes its colours from matugen's scheme for the wallpaper.
    readonly property var tones: ({
        black:     { label: "Black",     background: "#000000", foreground: "#ffffff", card: 0.38, light: false },
        slate:     { label: "Slate",     background: "#1b1f26", foreground: "#ffffff", card: 0.6, light: false },
        espresso:  { label: "Espresso",  background: "#1e1a17", foreground: "#f2ede6", card: 0.6, light: false },
        light:     { label: "Light",     background: "#ffffff", foreground: "#3c3c43", card: 0.65, light: true },
        mist:      { label: "Mist",      background: "#f2f2f7", foreground: "#1c1c1e", card: 0.65, light: true },
        ivory:     { label: "Ivory",     background: "#faf7f0", foreground: "#3b3630", card: 0.65, light: true },
        wallpaper: { label: "Wallpaper", background: colors.surface, foreground: colors.surfaceText, card: 0.6, light: false }
    })
    // Espresso until the settings are read (and for a name it does not know).
    readonly property string toneName: appearance?.tone in tones ? appearance.tone : "espresso"
    readonly property var tone: tones[toneName] ?? tones.espresso

    function setTone(name: string): void {
        if (name in tones) appearance.tone = name;
    }

    // Tone
    readonly property color background: tone.background
    readonly property color foreground: tone.foreground
    readonly property real cardOpacity: tone.card
    readonly property color card: Qt.alpha(background, cardOpacity)
    readonly property color rim: tone.light ? Qt.rgba(1, 1, 1, 0.5) : fg(0.08)
    readonly property color accent: tone.light ? Qt.darker(colors.accent, 1.5) : colors.accent  // darker reads on light
    readonly property color positive: tone.light ? "#1f9d3a" : "#3dff3d"
    readonly property color warning: "#ff5f56"
    readonly property color selection: Qt.rgba(0, 0, 0, tone.light ? 0.1 : 0.4)  // the picked row in a list

    // Foreground at an opacity: secondary text, hover fills, idle items. On
    // a light tone, text (0.3 and up) is lifted so it still reads.
    function fg(alpha: real): color {
        return Qt.alpha(foreground, alpha >= 0.3 && tone.light ? Math.min(1, alpha + 0.25) : alpha);
    }

    // Type
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int rowFontSize: 13     // rows in panels
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

    // Bar panels: a card grows down into one, and widens to at least this
    readonly property int barPanelWidth: 444

    // OSD: as wide as the max with a bar, else fitted to its row
    readonly property int osdMaxWidth: 360
    readonly property int osdMinWidth: 160

    IpcHandler {
        target: "theme"

        function reload(): void {
            file.reload();
        }

        function tone(name: string): void {
            theme.setTone(name);
        }
    }

    FileView {
        path: theme.stateDir + "/appearance.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: appearance
            property string tone: "espresso"
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
            property string surface: "#1e1a17"
            property string surfaceText: "#f2ede6"  // not onSurface: that reads as a handler
        }
    }
}
