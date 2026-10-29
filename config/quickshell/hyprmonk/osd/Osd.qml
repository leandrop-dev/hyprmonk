// The OSD: a card in the middle of the focused screen that says what just
// changed and hides itself. It follows volume and microphone (level and mute),
// the audio output, the keyboard layout, Caps and Num Lock, play/pause, do not
// disturb, game mode and the power profile. Clicks pass through it.
//
// IPC: qs -c hyprmonk ipc call osd display ICON TITLE CAPTION VALUE  (VALUE < 0: no bar)
//      qs -c hyprmonk ipc call osd locks  (Hyprland's Caps/Num Lock binds)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs
import qs.services

Scope {
    id: root

    property string icon: ""
    property string title: ""
    property string caption: ""
    property int value: -1  // 0-100 draws a bar; below 0, none
    property bool open: false

    // Changes in the first moments are the starting state being read.
    property bool ready: false

    function show(icon: string, title: string, caption: string, value: int): void {
        if (!ready) return;
        const kick = open;
        root.icon = icon;
        root.title = title;
        root.caption = caption;
        root.value = value;
        open = true;
        hide.restart();
        if (kick) nudge.restart();
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: root.ready = true
    }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.open = false
    }

    // Volume and microphone. A new default device reports its own level as it
    // is read: not a change, so levels are ignored until it settles.
    Connections {
        target: Audio

        function onVolumeChanged() { root.announceVolume(); }
        function onMutedChanged() { root.announceVolume(); }
        function onMicVolumeChanged() { root.announceMic(); }
        function onMicMutedChanged() { root.announceMic(); }
        function onSinkChanged() { outputSettle.restart(); }
        function onSourceChanged() { inputSettle.restart(); }
    }

    function announceVolume(): void {
        if (outputSettle.running) return;
        const percent = Math.round(Audio.volume * 100);
        show(Audio.volumeIcon, "Volume", Audio.muted ? "Muted" : percent + "%", Audio.muted ? 0 : percent);
    }

    function announceMic(): void {
        if (inputSettle.running) return;
        const percent = Math.round(Audio.micVolume * 100);
        show(Audio.micIcon, "Microphone", Audio.micMuted ? "Muted" : percent + "%", Audio.micMuted ? 0 : percent);
    }

    Timer {
        id: inputSettle
        interval: 800
    }

    // The output switches in steps (a headset leaving, then the fallback); say
    // it once it settles.
    property string shownOutput: ""

    Timer {
        id: outputSettle
        interval: 800
        onTriggered: {
            const name = Audio.sinkName;
            if (name === "" || name === root.shownOutput) return;
            const first = root.shownOutput === "";
            root.shownOutput = name;
            if (!first) root.show("\u{F04C3}", "Audio output", name, -1);
        }
    }

    // Keyboard layout and Caps/Num Lock, from the main keyboard's state in
    // Hyprland. Read at start, after each lock key, and on layout events (which
    // also come when any keyboard connects, hence the comparison).
    property var keyboard: null

    Process {
        id: devices
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = JSON.parse(text).keyboards.find(k => k.main);
                if (!now) return;
                const was = root.keyboard;
                root.keyboard = now;
                if (!was) return;
                if (now.capsLock !== was.capsLock)
                    root.show("\u{F0632}", "Caps Lock", now.capsLock ? "On" : "Off", -1);
                if (now.numLock !== was.numLock)
                    root.show("\u{F03A0}", "Num Lock", now.numLock ? "On" : "Off", -1);
                if (now.active_keymap !== was.active_keymap)
                    root.show("\u{F030C}", "Keyboard layout", now.active_keymap, -1);
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout") devices.running = true;
        }
    }

    // Play and pause, from any player that has a track with a length (a
    // browser's notification sound has none).
    Variants {
        model: Mpris.players.values

        Connections {
            required property MprisPlayer modelData

            target: modelData

            function onIsPlayingChanged(): void {
                const player = modelData;
                if (!player.lengthSupported || player.length <= 0) return;
                const track = [player.trackTitle, player.trackArtist].filter(s => s).join(" · ");
                root.show(player.isPlaying ? "\u{F040A}" : "\u{F03E4}", player.isPlaying ? "Playing" : "Paused", track, -1);
            }
        }
    }

    Connections {
        target: Notifications

        function onDoNotDisturbChanged(): void {
            root.show(Notifications.doNotDisturb ? "\u{F009B}" : "\u{F009A}", "Do not disturb",
                      Notifications.doNotDisturb ? "On" : "Off", -1);
        }
    }

    // Game mode also switches the power profile: say game mode, not both.
    Connections {
        target: GameMode

        function onOnChanged(): void {
            root.show("\u{F0297}", "Game mode", GameMode.on ? "On" : "Off", -1);
            gameSettle.restart();
        }
    }

    Timer {
        id: gameSettle
        interval: 1000
    }

    Connections {
        target: Power

        function onProfileNameChanged(): void {
            if (gameSettle.running) return;
            root.show("\u{F04C5}", "Power profile", Power.profileName, -1);
        }
    }

    IpcHandler {
        target: "osd"

        // Not "show": `qs ipc call osd show` parses as the `ipc show` command.
        function display(icon: string, title: string, caption: string, value: int): void {
            root.show(icon, title, caption, value);
        }

        function locks(): void {
            devices.running = true;
        }
    }

    PanelWindow {
        id: window

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        // Kept mapped, empty, while a centred card is open: Hyprland hands
        // the keyboard to a window whenever a layer unmaps, even away from
        // a card that holds it (services/Overlays.qml).
        visible: root.open || card.opacity > 0 || Overlays.open !== ""

        // No anchors: the compositor centres it.
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        mask: Region {}

        WlrLayershell.namespace: "hyprmonk-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card

            readonly property bool hasBar: root.value >= 0

            width: hasBar ? Theme.osdMaxWidth
                          : Math.round(Math.max(Theme.osdMinWidth, Math.min(Theme.osdMaxWidth, row.implicitWidth + 32)))
            height: column.implicitHeight + 32
            radius: Theme.panelRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.rim

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: column

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 12

                RowLayout {
                    id: row

                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        id: glyph
                        text: root.icon
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: 22

                        // A small kick when it changes while shown.
                        SequentialAnimation {
                            id: nudge
                            NumberAnimation { target: glyph; property: "scale"; to: 1.2; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: glyph; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        textFormat: Text.PlainText
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.maximumWidth: 180
                        text: root.caption
                        textFormat: Text.PlainText
                        color: Theme.fg(0.6)
                        font.family: Theme.font
                        font.pixelSize: Theme.bodyFontSize
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: card.hasBar
                    implicitHeight: 6
                    radius: 3
                    color: Theme.fg(0.12)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: Theme.fg(0.85)
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
