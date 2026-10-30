// The connection: Ethernet, or the Wi-Fi's signal; dim without one. Click: the
// network panel.
import QtQuick
import qs.services

Module {
    interactive: true
    icon: Net.icon
    dim: !Net.online
    tooltip: Net.summary

    onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("network"); }
}
