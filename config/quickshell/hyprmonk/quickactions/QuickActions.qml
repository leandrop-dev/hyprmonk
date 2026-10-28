// Quick actions (Super+K): a card in the middle of the focused screen with
// the switches used most, under their sections. Typing filters them (the
// letters in order, gaps allowed: "gm" finds "Game mode"); the arrows or Tab
// move, Enter or a click runs one and closes the card; Escape or a click
// elsewhere closes it.
//
// IPC: qs -c hyprmonk ipc call quickactions toggle
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null
    property string query: ""
    property int current: 0

    // Hyprland's main keyboard, read on each open: its layouts and the one in use.
    property var layouts: []
    property int layoutIndex: 0

    readonly property list<Action> actions: [
        Action {
            section: "Audio"
            icon: "\u{F04C3}"
            label: "Audio output"
            value: Audio.sinkName
            available: Audio.sinks.length > 0
            onRun: {
                const sinks = Audio.sinks;
                Audio.setDefault(sinks[(sinks.indexOf(Audio.sink) + 1) % sinks.length]);
            }
        },
        Action {
            section: "Audio"
            icon: "\u{F036C}"
            label: "Microphone"
            on: !Audio.micMuted
            available: Audio.source?.audio != null
            onRun: Audio.source.audio.muted = !Audio.source.audio.muted
        },
        Action {
            section: "System"
            icon: "\u{F0297}"
            label: "Game mode"
            on: GameMode.on
            onRun: GameMode.toggle()
        },
        Action {
            section: "System"
            icon: "\u{F009B}"
            label: "Do not disturb"
            on: Notifications.doNotDisturb
            onRun: Notifications.doNotDisturb = !Notifications.doNotDisturb
        },
        Action {
            section: "System"
            icon: "\u{F04C5}"
            label: "Power profile"
            value: Power.profileName
            onRun: Power.nextProfile()
        },
        Action {
            section: "System"
            icon: "\u{F030C}"
            label: "Keyboard layout"
            value: root.layouts[root.layoutIndex] ?? ""
            available: root.layouts.length > 1
            onRun: Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])
        }
    ]

    readonly property var available: actions.filter(a => a.available)
    readonly property var shown: available.filter(a => matches(a.label, query))

    // The letters typed appear in the label in order (spaces ignored).
    function matches(label: string, typed: string): bool {
        const text = label.toLowerCase();
        let at = 0;
        for (const c of typed.toLowerCase().replace(/\s/g, "")) {
            at = text.indexOf(c, at) + 1;
            if (at === 0) return false;
        }
        return true;
    }

    // A heading goes before the first action of each section.
    function startsSection(list: var, index: int): bool {
        return index === 0 || list[index].section !== list[index - 1].section;
    }

    readonly property int rowHeight: 42
    readonly property int headingHeight: 26

    function listHeight(list: var): int {
        if (list.length === 0) return rowHeight;
        return list.reduce((sum, _, i) => sum + rowHeight + (startsSection(list, i) ? headingHeight : 0), 0);
    }

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        devices.running = true;
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null;
        search.text = "";
        query = "";
        current = 0;
        open = true;
        search.forceActiveFocus();
    }

    function move(step: int): void {
        if (shown.length > 0) current = (current + step + shown.length) % shown.length;
    }

    function run(action: Action): void {
        if (!action) return;
        open = false;
        action.run();
    }

    IpcHandler {
        target: "quickactions"

        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboard = JSON.parse(text).keyboards.find(k => k.main);
                root.layouts = keyboard?.layout ? keyboard.layout.split(",") : [];
                root.layoutIndex = keyboard?.active_layout_index ?? 0;
            }
        }
    }

    // A layout switched from here (or anywhere) shows on the next open too.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout") devices.running = true;
        }
    }

    PanelWindow {
        id: window

        readonly property int margin: 32  // room around the card as it unfolds
        readonly property int top: 44     // the search line, above the list

        screen: root.screen
        visible: root.open || card.opacity > 0
        color: "transparent"
        // As tall as the whole list, so filtering shrinks the card up towards
        // a fixed top instead of moving it.
        implicitWidth: 420 + margin * 2
        implicitHeight: top + root.listHeight(root.available) + 12 + margin * 2
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: card }

        WlrLayershell.namespace: "hyprmonk-quickactions"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        HyprlandFocusGrab {
            windows: [window]
            active: root.open
            onCleared: root.open = false
        }

        Rectangle {
            id: card

            x: window.margin
            y: window.margin
            width: 420
            height: window.top + root.listHeight(root.shown) + 12
            radius: Theme.panelRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.rim
            clip: true

            Behavior on height {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            // Unfolds down from its top edge.
            opacity: root.open ? 1 : 0
            transform: Rotation {
                origin.x: card.width / 2
                origin.y: 0
                axis { x: 1; y: 0; z: 0 }
                angle: root.open ? 0 : -90

                Behavior on angle {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            TextInput {
                id: search

                x: 20
                y: 16
                width: card.width - 40
                focus: true
                color: Theme.foreground
                selectionColor: Qt.alpha(Theme.accent, 0.4)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize

                onTextEdited: {
                    root.query = text;
                    root.current = 0;
                }

                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onReturnPressed: root.run(root.shown[root.current])
                Keys.onEnterPressed: root.run(root.shown[root.current])
                Keys.onEscapePressed: root.open = false

                Text {
                    visible: !search.text
                    text: "Quick actions"
                    color: Theme.fg(Theme.dimOpacity)
                    font: search.font
                }
            }

            Item {
                id: list

                x: 12
                y: window.top
                width: card.width - 24
                height: root.listHeight(root.shown)

                // The picked row; slides to the next one.
                Rectangle {
                    // itemAt() is not watched: reading count re-reads it as rows come and go.
                    readonly property Item row: rows.count > root.current ? rows.itemAt(root.current).row : null

                    visible: row !== null
                    x: 0
                    y: row ? row.parent.y + row.y : 0
                    width: list.width
                    height: root.rowHeight
                    radius: 10
                    color: Theme.selection

                    Behavior on y {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                Column {
                    width: list.width

                    Repeater {
                        id: rows

                        model: root.shown

                        Column {
                            id: entry

                            required property Action modelData
                            required property int index
                            readonly property bool picked: index === root.current
                            readonly property alias row: row

                            width: list.width

                            SectionLabel {
                                visible: root.startsSection(root.shown, entry.index)
                                height: root.headingHeight
                                leftPadding: 12
                                bottomPadding: 6
                                verticalAlignment: Text.AlignBottom
                                text: entry.modelData.section
                                font.pixelSize: 10
                                font.capitalization: Font.MixedCase
                            }

                            Item {
                                id: row

                                width: list.width
                                height: root.rowHeight

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.current = entry.index
                                    onClicked: root.run(entry.modelData)
                                }

                                Text {
                                    id: glyph

                                    x: 12
                                    width: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: entry.modelData.icon
                                    color: entry.modelData.on === true ? Theme.accent : Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: 18
                                    scale: entry.picked ? 1.15 : 1

                                    Behavior on scale {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                Text {
                                    anchors.left: glyph.right
                                    anchors.leftMargin: 12
                                    anchors.right: pill.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.modelData.label
                                    color: Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                }

                                Chip {
                                    id: pill

                                    readonly property bool isSwitch: entry.modelData.on !== undefined

                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 160)
                                    visible: isSwitch || entry.modelData.value !== ""
                                    text: isSwitch ? (entry.modelData.on ? "on" : "off") : entry.modelData.value
                                    on: entry.modelData.on
                                    onClicked: root.run(entry.modelData)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.shown.length === 0
                    x: 12
                    height: root.rowHeight
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing matches"
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
