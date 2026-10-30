// Bluetooth, on a machine with an adapter; dim while off. Click: the Bluetooth
// panel.
import QtQuick
import qs.services

Module {
    visible: Bluez.adapter !== null
    interactive: true
    icon: Bluez.icon
    dim: !Bluez.on
    tooltip: Bluez.summary

    onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("bluetooth"); }
}
