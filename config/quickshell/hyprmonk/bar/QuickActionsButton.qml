// Opens quick actions (also Super+K).
import QtQuick
import qs.services

Module {
    interactive: true
    icon: "\u{F1542}"
    active: Overlays.open === "quickactions"

    onClicked: button => { if (button === Qt.LeftButton) Overlays.toggle("quickactions"); }
}
