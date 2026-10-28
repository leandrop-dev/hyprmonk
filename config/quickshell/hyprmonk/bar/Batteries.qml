// Peripheral batteries (services/Battery.qml), one module each. Click: the
// battery panel.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

RowLayout {
    id: root

    property bool active: false

    spacing: 2

    Repeater {
        model: Battery.devices

        Module {
            required property var modelData

            interactive: true
            active: root.active
            icon: modelData.charging ? "\u{F0084}" : modelData.icon
            label: modelData.percent + "%"
            color: Battery.isLow(modelData) ? Theme.warning : Theme.foreground

            onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("batteries"); }
        }
    }
}
