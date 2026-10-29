// The screenshot mode's card: while Hyprland's "screenshot" submap is on
// (Print), a card in the middle of the focused screen lists its keys, read
// from Hyprland (hypr/binds.lua): what each takes, to save or to copy. It
// disappears at once when the mode ends, before the picture is taken.
// Clicks pass through it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

Scope {
    id: root

    readonly property string submap: "screenshot"
    readonly property string copySuffix: " to clipboard"
    property bool open: false
    property var rows: []    // [{description, save, copy}]: keys
    property string cancel: ""

    function modifiers(mask: int): var {
        return [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
            .filter(([bit]) => mask & bit)
            .map(([, name]) => name);
    }

    function keysOf(bind: var): string {
        const key = bind.key === "Escape" ? "Esc" : bind.key;
        return [...modifiers(bind.modmask), key].join(" + ");
    }

    // "Region" saves; "Region to clipboard" is the same row's copy key.
    function load(binds: var): void {
        const rows = [];
        const cancel = [];
        for (const bind of binds.filter(b => b.submap === submap)) {
            const copy = bind.description.endsWith(copySuffix);
            const description = copy ? bind.description.slice(0, -copySuffix.length) : bind.description;
            if (description === "Cancel") {
                cancel.push(keysOf(bind));
                continue;
            }
            let row = rows.find(r => r.description === description);
            if (!row) {
                row = { description, save: "", copy: "" };
                rows.push(row);
            }
            row[copy ? "copy" : "save"] = keysOf(bind);
        }
        root.rows = rows;
        root.cancel = cancel.join(" / ");
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "submap") return;
            root.open = event.data === root.submap;
            if (root.open) reader.running = true;
        }
    }

    // Read once at start too, so the first open has its keys at once.
    Process {
        id: reader
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.load(JSON.parse(text))
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        // No fade out: gone before the screen freezes for the picture.
        visible: root.open

        // No anchors: the compositor centres it.
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        mask: Region {}

        WlrLayershell.namespace: "hyprmonk-screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card

            width: Theme.osdMaxWidth
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
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 12

                    Text {
                        text: "\u{F0100}"
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: 22
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Screenshot"
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }
                    Dim { text: "Save"; Layout.preferredWidth: root.keyWidth; horizontalAlignment: Text.AlignHCenter }
                    Dim { text: "Copy"; Layout.preferredWidth: root.keyWidth; horizontalAlignment: Text.AlignHCenter }
                }

                Repeater {
                    model: root.rows

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: modelData.description
                            textFormat: Text.PlainText
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.rowFontSize
                            elide: Text.ElideRight
                        }

                        Key { text: modelData.save }
                        Key { text: modelData.copy }
                    }
                }

                Dim {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.cancel !== ""
                    text: root.cancel + " cancels"
                }
            }
        }
    }

    readonly property int keyWidth: 84

    component Dim: Text {
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    // A key in a chip, as in the key guide; an empty one leaves its place.
    component Key: Rectangle {
        property alias text: label.text

        Layout.preferredWidth: root.keyWidth
        implicitHeight: 22
        radius: 6
        color: text ? Theme.fg(0.08) : "transparent"

        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
            font.weight: Font.DemiBold
        }
    }
}
