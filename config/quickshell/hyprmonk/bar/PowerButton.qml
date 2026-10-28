// Opens the power menu (also Super+Shift+E).
import QtQuick
import qs.services

Module {
    interactive: true
    icon: "\u{F0425}"
    active: Overlays.open === "power"

    onClicked: button => { if (button === Qt.LeftButton) Overlays.toggle("power"); }
}
