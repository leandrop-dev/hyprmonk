// Colours, type and sizes for every surface.
//
// The look: dark translucent cards with a faint rim, monospace type, and one
// accent taken from the wallpaper (or the tone's own). The tone (background and text) is one of
// `tones`; the accent comes from matugen's colors.json in the state
// directory, and the defaults below apply until matugen has run.
//
// matugen's post_hook calls `qs -c hyprmonk ipc call theme reload`: a file
// watch alone misses the first run, when the file does not exist yet.
//
// IPC: qs -c hyprmonk ipc call theme tone NAME  (noir or wallpaper)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hyprmonk"

    // Tones: the background, the text and how opaque cards are. One is in
    // use (quick actions > Appearance, kept in appearance.json); "wallpaper"
    // and "wallpaperlight" take their colours from matugen's schemes for the
    // wallpaper. A tone may
    // bring its own accent (and green) instead of the wallpaper's. A light
    // one (`light: true`) needs more card opacity, or a dark wallpaper greys
    // it. The rest of them are in Tones.qml.
    readonly property var tones: Object.assign({
        // From cosmic-noir-theme: charcoal, fog text, orange, sage.
        noir:      { label: "Noir",      background: "#171717", foreground: "#ccd0cf", card: 0.88, light: false,
                     accent: "#f25623", positive: "#88a57d", icons: "" },
        wallpaper: { label: "Wallpaper", background: colors.surface, foreground: colors.surfaceText, card: 0.78, light: false },
        // Having an accent, it paints apps as a tone of its own does, over
        // matugen's dark colours.
        wallpaperlight: { label: "Wallpaper Light", background: colors.lightSurface, foreground: colors.lightSurfaceText,
                          card: 0.92, light: true, accent: colors.lightAccent }
    }, Tones.list)
    // Noir until the settings are read (and for a name it does not know, such
    // as a tone that was dropped).
    // A previewed tone (quick actions, while moving through them) shows
    // without being saved.
    readonly property string savedTone: appearance?.tone in tones ? appearance.tone : "noir"
    property string previewTone: ""
    readonly property string toneName: previewTone in tones ? previewTone : savedTone
    readonly property var tone: tones[toneName] ?? tones.noir

    function setTone(name: string): void {
        if (name in tones) appearance.tone = name;
    }

    // Tone
    readonly property color background: tone.background
    readonly property color foreground: tone.foreground
    readonly property real cardOpacity: tone.card
    readonly property color card: Qt.alpha(background, cardOpacity)
    readonly property color rim: tone.light ? Qt.rgba(1, 1, 1, 0.5) : fg(0.08)
    readonly property color accent: tone.accent ?? (tone.light ? Qt.darker(colors.accent, 1.5) : colors.accent)  // darker reads on light
    readonly property color positive: tone.positive ?? (tone.light ? "#1f9d3a" : "#3dff3d")
    readonly property color warning: "#ff5f56"
    readonly property color selection: Qt.rgba(0, 0, 0, tone.light ? 0.1 : 0.4)  // the picked row in a list
    readonly property color wallpaperAccent: colors.accent  // whatever the tone (ThemeOutputs.qml)
    readonly property var wallpaperColours: colors  // matugen's, for apps (ThemeOutputs.qml)

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
            property string tone: "noir"
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
            // For apps' colour schemes (ThemeOutputs.qml): text a step back, the
            // surface's levels from the darkest, and errors.
            property string surfaceMuted: "#d5c3b5"
            property string surfaceLowest: "#18120d"
            property string surfaceLow: "#221a15"
            property string surfaceContainer: "#261e19"
            property string surfaceHigh: "#312823"
            property string surfaceHighest: "#3d332d"
            property string error: "#ffb4ab"
            // The Wallpaper Light tone.
            property string lightSurface: "#fff8f5"
            property string lightSurfaceText: "#201a17"
            property string lightAccent: "#8f4c00"
        }
    }
}
