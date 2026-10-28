// The power menu: a row of tiles in the middle of the focused screen, from
// the bar's power button, Super+Shift+E or quick actions. Suspend runs at
// once; log out, reboot and shut down ask for a second press on the same
// tile. The arrows or Tab move, Enter or a tile's letter presses it, Escape
// or a click elsewhere closes the menu.
//
// IPC: qs -c hyprmonk ipc call overlays toggle power
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Overlays.open === "power"
    property int current: 0
    property int armed: -1  // the tile waiting for its second press

    readonly property int tileWidth: 104
    readonly property int tileHeight: 112
    readonly property int gap: 8

    readonly property var actions: [
        { icon: "\u{F0343}", label: "Log out",   key: "e", confirm: true,  command: ["uwsm", "stop"] },
        { icon: "\u{F0904}", label: "Suspend",   key: "u", confirm: false, command: ["systemctl", "suspend"] },
        { icon: "\u{F0709}", label: "Reboot",    key: "r", confirm: true,  command: ["systemctl", "reboot"] },
        { icon: "\u{F0425}", label: "Shut down", key: "s", confirm: true,  command: ["systemctl", "poweroff"] }
    ]

    onOpenChanged: {
        if (!open) return;
        current = 0;
        armed = -1;
        keys.forceActiveFocus();
    }

    // Moving away disarms.
    onCurrentChanged: armed = -1

    function move(step: int): void {
        current = (current + step + actions.length) % actions.length;
    }

    function press(index: int): void {
        const action = actions[index];
        current = index;
        if (action.confirm && armed !== index) {
            armed = index;
            return;
        }
        Overlays.close();
        Quickshell.execDetached(action.command);
    }

    Overlay {
        name: "hyprmonk-power"
        open: root.open
        cardWidth: root.actions.length * (root.tileWidth + root.gap) - root.gap + 24
        cardHeight: root.tileHeight + 24
        onDismissed: Overlays.close()

        Item {
            id: keys

            focus: true

            Keys.onLeftPressed: root.move(-1)
            Keys.onRightPressed: root.move(1)
            Keys.onTabPressed: root.move(1)
            Keys.onBacktabPressed: root.move(-1)
            Keys.onReturnPressed: root.press(root.current)
            Keys.onEnterPressed: root.press(root.current)
            Keys.onEscapePressed: Overlays.close()
            Keys.onPressed: event => {
                const index = root.actions.findIndex(a => a.key === event.text.toLowerCase());
                if (index >= 0) {
                    root.press(index);
                    event.accepted = true;
                }
            }
        }

        // The picked tile; slides to the next one.
        Rectangle {
            x: 12 + root.current * (root.tileWidth + root.gap)
            y: 12
            width: root.tileWidth
            height: root.tileHeight
            radius: 10
            color: Theme.selection

            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Row {
            x: 12
            y: 12
            spacing: root.gap

            Repeater {
                model: root.actions

                Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool picked: index === root.current
                    readonly property bool armed: index === root.armed

                    width: root.tileWidth
                    height: root.tileHeight

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = tile.index
                        onClicked: root.press(tile.index)
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            color: tile.armed ? Theme.warning : Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: 36
                            scale: tile.picked ? 1.15 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 120 }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.armed ? "Again" : tile.modelData.label
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.rowFontSize
                            font.bold: tile.armed
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.key.toUpperCase()
                            color: Theme.fg(Theme.dimOpacity)
                            font.family: Theme.font
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
