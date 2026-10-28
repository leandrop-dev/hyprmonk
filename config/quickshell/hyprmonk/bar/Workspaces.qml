// The workspaces on this bar's monitor, as slim pills: the active one wider
// and in the accent colour. A click switches to it.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    implicitWidth: pills.implicitWidth + 12
    implicitHeight: Theme.barHeight - Theme.cardPadding * 2

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: Hyprland.workspaces.values
                .filter(ws => ws.id > 0 && ws.monitor === root.monitor)
                .sort((a, b) => a.id - b.id)

            Rectangle {
                id: pill

                required property HyprlandWorkspace modelData
                readonly property bool active: modelData.active

                width: active ? 30 : 16
                height: 18
                radius: height / 2
                color: active ? Qt.alpha(Theme.accent, 0.55) : Theme.fg(mouse.containsMouse ? 0.24 : 0.16)
                border.width: 1
                border.color: active ? Qt.alpha(Theme.accent, 0.8) : Theme.fg(0.22)

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                BarText {
                    anchors.centerIn: parent
                    text: pill.modelData.name
                    font.pixelSize: Theme.smallFontSize
                    color: pill.modelData.urgent ? Theme.warning : Theme.foreground
                    opacity: pill.active ? 1 : 0.4
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // The config is Lua, so dispatches are Lua too.
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${pill.modelData.id} })`)
                }
            }
        }
    }
}
