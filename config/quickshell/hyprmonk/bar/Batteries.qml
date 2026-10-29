// Peripheral batteries (services/Battery.qml), one module each. Click: the
// battery panel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

RowLayout {
    id: root

    property bool active: false

    spacing: 2

    Repeater {
        // ScriptModel keeps a device's module when another comes or goes.
        model: ScriptModel {
            values: Battery.keys
        }

        Module {
            required property string modelData
            readonly property var device: Battery.device(modelData)

            interactive: true
            active: root.active
            icon: device.charging ? "\u{F0084}" : device.icon
            label: device.percent + "%"
            color: Battery.isLow(device) ? Theme.warning : Theme.foreground

            onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("batteries"); }
        }
    }
}
