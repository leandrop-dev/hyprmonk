// The workspaces on this bar's monitor, in order; the active one is filled.
// A click switches to it.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Row {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    spacing: 4

    Repeater {
        model: Hyprland.workspaces.values
            .filter(ws => ws.id > 0 && ws.monitor === root.monitor)
            .sort((a, b) => a.id - b.id)

        Rectangle {
            id: pill

            required property HyprlandWorkspace modelData

            width: modelData.active ? 32 : 24
            height: 22
            radius: height / 2
            color: modelData.active ? Theme.accent : (mouse.containsMouse ? Theme.surfaceHigh : "transparent")

            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            BarText {
                anchors.centerIn: parent
                text: pill.modelData.name
                color: pill.modelData.active ? Theme.onAccent : (pill.modelData.urgent ? Theme.warning : Theme.textDim)
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                // The config is Lua, so dispatches are Lua too.
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${pill.modelData.id} })`)
            }
        }
    }
}
