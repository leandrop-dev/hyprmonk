// The distro logo; a click opens the launcher (also Super+Space).
import QtQuick
import qs.services

Module {
    icon: Distro.logo
    iconSize: 20
    interactive: true
    active: Overlays.open === "launcher"

    onClicked: button => { if (button === Qt.LeftButton) Overlays.toggle("launcher"); }
}
