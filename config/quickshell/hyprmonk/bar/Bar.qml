// The bar along the top of one screen: workspaces left, clock centre,
// system status right, on a single translucent strip.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 36
    color: "transparent"

    WlrLayershell.namespace: "hyprmonk-bar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        anchors.bottomMargin: 0
        radius: Theme.radius
        color: Qt.alpha(Theme.surface, 0.82)

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        Clock {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Temperature {}
            Batteries {}
            Volume {}
        }
    }
}
