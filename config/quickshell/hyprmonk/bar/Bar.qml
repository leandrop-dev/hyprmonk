// The bar on one screen: three floating cards (left, centre, right) on a
// transparent strip. Only the cards are drawn, so Hyprland's blur (rules.lua,
// namespace hyprmonk-bar) applies to them alone.
import QtQuick
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
    implicitHeight: Theme.barHeight + Theme.barGap * 2
    color: "transparent"

    WlrLayershell.namespace: "hyprmonk-bar"
    WlrLayershell.layer: WlrLayer.Top

    Card {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.verticalCenter: parent.verticalCenter

        Launcher {}
        Workspaces { screen: bar.screen }
        Overview {}
        Temperature {}
    }

    Card {
        anchors.centerIn: parent

        Media {}
    }

    Card {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.verticalCenter: parent.verticalCenter

        Batteries {}
        Volume {}
        Microphone {}
        NotificationBell {}
        Clock {}
    }
}
