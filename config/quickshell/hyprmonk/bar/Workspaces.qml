// The workspaces on this bar's monitor, as slim pills: the active one wider
// and in the accent colour. A click switches to it. With a count picked in
// Settings > Bar, 1 to that many always show: one not open yet is an empty
// pill, unless it is open on another monitor.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int count: Settings.barChoice("workspaces")

    // The empty pills' stand-ins, made once each so the pills keep them.
    property var spare: ({})
    function spareFor(id: int): var {
        if (!spare[id]) spare[id] = { id, name: String(id), active: false, urgent: false, empty: true };
        return spare[id];
    }

    implicitWidth: pills.implicitWidth + 12
    implicitHeight: Theme.barHeight - Theme.cardPadding * 2

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            // ScriptModel keeps the pills that stay, and their width
            // animation, when a workspace comes or goes.
            model: ScriptModel {
                values: {
                    const open = Hyprland.workspaces.values.filter(ws => ws.id > 0);
                    const here = open.filter(ws => ws.monitor === root.monitor);
                    const shown = here.slice();
                    for (let id = 1; id <= root.count; id++)
                        if (!open.some(ws => ws.id === id)) shown.push(root.spareFor(id));
                    return shown.sort((a, b) => a.id - b.id);
                }
            }

            Rectangle {
                id: pill

                required property var modelData
                readonly property bool active: modelData.active
                readonly property bool empty: modelData.empty === true

                width: active ? 30 : 16
                height: 18
                radius: height / 2
                color: active ? Qt.alpha(Theme.accent, 0.55)
                     : Theme.fg(empty ? (mouse.containsMouse ? 0.12 : 0.04) : (mouse.containsMouse ? 0.24 : 0.16))
                border.width: 1
                border.color: active ? Qt.alpha(Theme.accent, 0.8) : Theme.fg(empty ? 0.14 : 0.22)

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                BarText {
                    anchors.centerIn: parent
                    text: pill.modelData.name
                    font.pixelSize: Theme.smallFontSize
                    color: pill.modelData.urgent ? Theme.warning : Theme.foreground
                    opacity: pill.active ? 1 : pill.empty ? 0.25 : 0.4
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
