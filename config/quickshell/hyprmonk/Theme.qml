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
// IPC: qs -c hyprmonk ipc call theme tone NAME  (a key of `tones`)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hyprmonk"

    // Tones: the background, the text and how opaque cards are. One is in
    // use (Settings > Appearance, kept in appearance.json); "wallpaper"
    // and "wallpaperlight" take their colours from matugen's schemes for the
    // wallpaper. A tone may
    // bring its own accent (and green) instead of the wallpaper's. A light
    // one (`light: true`) needs more card opacity, or a dark wallpaper greys
    // it. The rest of them are in Tones.qml.
    //
    // Ask for a tone through toneOf() or baseTone(): a new wallpaper then only
    // reaches what is using one of the two tones made from it.
    // From cosmic-noir-theme: charcoal, fog text, orange, sage.
    readonly property var noir: ({ label: "Noir", background: "#171717", foreground: "#ccd0cf", card: 0.88, light: false,
                                   accent: "#f25623", positive: "#88a57d", icons: "" })
    readonly property var wallpaperTone: ({ label: "Wallpaper", background: colors.surface, foreground: colors.surfaceText,
                                            card: 0.78, light: false })
    // Having an accent, it paints apps as a tone of its own does, over
    // matugen's dark colours.
    readonly property var wallpaperLightTone: ({ label: "Wallpaper Light", background: colors.lightSurface,
                                                 foreground: colors.lightSurfaceText, card: 0.92, light: true,
                                                 accent: colors.lightAccent })
    readonly property var tones: Object.assign({ noir, wallpaper: wallpaperTone, wallpaperlight: wallpaperLightTone }, Tones.list)
    // Noir until the settings are read (and for a name it does not know, such
    // as a tone that was dropped).
    // A previewed tone (Settings > Appearance, under the pointer) shows
    // without being saved.
    readonly property string savedTone: appearance?.tone in tones ? appearance.tone : "noir"
    property string previewTone: ""
    readonly property string toneName: previewTone in tones ? previewTone : savedTone
    readonly property var tone: toneOf(toneName)

    function baseTone(name: string): var {
        if (name === "wallpaper") return wallpaperTone;
        if (name === "wallpaperlight") return wallpaperLightTone;
        return Tones.list[name] ?? noir;
    }

    // With the text colour Settings gave it, which apps follow too. The cards'
    // opacity and blur stay apart: moving them does not rebuild the apps' themes.
    function toneOf(name: string): var {
        const text = appearance?.text?.[name] ?? "";
        return /^#[0-9a-f]{6}$/i.test(text) ? Object.assign({}, baseTone(name), { foreground: text }) : baseTone(name);
    }

    function setTone(name: string): void {
        if (name in tones) appearance.tone = name;
    }

    // Settings > Tone changes the saved tone; each keeps its own.
    readonly property bool cardBlur: appearance?.blur?.[savedTone] !== false
    // The saved tone's card opacity (cardOpacity follows a previewed tone).
    readonly property real savedCardOpacity: appearance?.opacity?.[savedTone] >= 0.3
        ? Math.min(1, appearance.opacity[savedTone]) : toneOf(savedTone).card
    readonly property bool toneAdjusted: [appearance?.opacity, appearance?.text, appearance?.blur].some(kept => kept && savedTone in kept)

    function adjust(kept: var, value: var): var {
        return Object.assign({}, kept, { [savedTone]: value });
    }

    function setCardOpacity(value: real): void {
        appearance.opacity = adjust(appearance.opacity, value);
    }

    function setCardBlur(on: bool): void {
        appearance.blur = adjust(appearance.blur, on);
    }

    function setTextColour(colour: string): void {
        appearance.text = adjust(appearance.text, colour.toLowerCase());
    }

    function resetTone(): void {
        const without = kept => {
            const left = Object.assign({}, kept);
            delete left[savedTone];
            return left;
        };
        appearance.opacity = without(appearance.opacity);
        appearance.text = without(appearance.text);
        appearance.blur = without(appearance.blur);
    }

    // Whether text in this colour reads on the saved tone's background: a
    // contrast of 3:1, the least WCAG allows for large text.
    function readable(colour: string): bool {
        const luminance = shade => {
            const [r, g, b] = [shade.r, shade.g, shade.b].map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        };
        const one = luminance(Qt.color(colour));
        const other = luminance(Qt.color(baseTone(savedTone).background));
        return (Math.max(one, other) + 0.05) / (Math.min(one, other) + 0.05) >= 3;
    }

    // Tone
    readonly property color background: tone.background
    readonly property color foreground: tone.foreground
    readonly property real cardOpacity: appearance?.opacity?.[toneName] >= 0.3 ? Math.min(1, appearance.opacity[toneName]) : tone.card
    readonly property color card: Qt.alpha(background, cardOpacity)
    readonly property color rim: tone.light ? Qt.rgba(1, 1, 1, 0.5) : fg(0.08)
    readonly property color accent: tone.accent ?? (tone.light ? Qt.darker(colors.accent, 1.5) : colors.accent)  // darker reads on light
    readonly property color positive: positiveOf(tone)
    readonly property color warning: "#ff5f56"
    readonly property color selection: Qt.rgba(0, 0, 0, tone.light ? 0.1 : 0.4)  // the picked row in a list
    readonly property color wallpaperAccent: colors.accent  // whatever the tone (ThemeOutputs.qml)
    readonly property var wallpaperColours: colors  // matugen's, for apps (ThemeOutputs.qml)

    // A path as a URL: `#`, `?` and `%` in a file name would otherwise read as
    // URL syntax, and the picture would not load.
    function fileUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // Of any tone: ThemeOutputs asks for the saved one, not a previewed one.
    function positiveOf(which: var): color {
        return which.positive ?? (which.light ? "#1f9d3a" : "#3dff3d");
    }

    // Foreground at an opacity: secondary text, hover fills, idle items. On
    // a light tone, text (0.3 and up) is lifted so it still reads.
    function fg(alpha: real): color {
        return Qt.alpha(foreground, alpha >= 0.3 && tone.light ? Math.min(1, alpha + 0.25) : alpha);
    }

    // Type. Two fonts, picked in Settings > Appearance > Fonts and kept in
    // appearance.json: the interface's (the shell, GTK and Qt apps, the
    // Floating layout's title bars and the login screen) and the monospace
    // one (the terminal, and code in apps). ThemeOutputs.qml hands them on.
    // A font without the shell's icons gets them from Symbols Nerd Font.
    // Until one is picked ("" kept), the shell and the terminal have
    // defaultFont and apps keep their own (appFont and appMonoFont empty).
    readonly property string defaultFont: "JetBrainsMono Nerd Font"
    readonly property string appFont: appearance.font
    readonly property string appMonoFont: appearance.monoFont
    readonly property string font: appFont || defaultFont
    readonly property string monoFont: appMonoFont || defaultFont

    // "" for the default.
    function setFont(family: string): void {
        appearance.font = family;
    }

    function setMonoFont(family: string): void {
        appearance.monoFont = family;
    }

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
    readonly property int notificationWidth: 500         // pop-ups and the notifications panel

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

    // A write reads the file back: changes made in one go would undo each
    // other, and a slider would write on every step.
    Timer {
        id: saving
        interval: 200
        onTriggered: appearanceFile.writeAdapter()
    }

    FileView {
        id: appearanceFile
        path: theme.stateDir + "/appearance.json"
        printErrors: false
        onAdapterUpdated: saving.restart()

        JsonAdapter {
            id: appearance
            property string tone: "noir"
            // By tone name: what Settings > Tone changed.
            property var opacity: ({})
            property var text: ({})
            property var blur: ({})
            property string font: ""  // "" for defaultFont
            property string monoFont: ""
        }
    }

    FileView {
        id: file
        path: theme.stateDir + "/theme/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.readColours(text())
    }

    // matugen's colours, set in one go: one by one, each would build the
    // tones again.
    property var colors: ({
        accent: "#ef8608",
        surface: "#1e1a17",
        surfaceText: "#f2ede6",
        // For apps' colour schemes (ThemeOutputs.qml): text a step back, the
        // surface's levels from the darkest, and errors.
        surfaceMuted: "#d5c3b5",
        surfaceLowest: "#18120d",
        surfaceLow: "#221a15",
        surfaceContainer: "#261e19",
        surfaceHigh: "#312823",
        surfaceHighest: "#3d332d",
        error: "#ffb4ab",
        // The Wallpaper Light tone.
        lightSurface: "#fff8f5",
        lightSurfaceText: "#201a17",
        lightAccent: "#8f4c00"
    })
    property string colorsRead: ""

    // The file comes twice for a wallpaper (the watch, matugen's reload). One
    // that does not parse is half written: the next change brings the rest.
    function readColours(json: string): void {
        if (json === colorsRead) return;
        try {
            colors = Object.assign({}, colors, JSON.parse(json));
            colorsRead = json;
        } catch (error) {}
    }
}
