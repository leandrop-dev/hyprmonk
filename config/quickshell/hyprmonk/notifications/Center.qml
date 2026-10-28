// Every notification still open, under the bar's right card: Super+N or a
// click on the bell. Do not disturb and clear all at the top; a click outside
// or Escape closes it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: window

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifications.centerOpen

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barGap
        right: Theme.barMargin
    }
    implicitWidth: Theme.panelWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "hyprmonk-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [window]
        active: window.visible
        onCleared: Notifications.centerOpen = false
    }

    Rectangle {
        id: panel

        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: Theme.panelRadius
        color: Theme.card
        border.width: 1
        border.color: Theme.rim
        focus: true
        Keys.onEscapePressed: Notifications.centerOpen = false

        ColumnLayout {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SectionLabel {
                    Layout.fillWidth: true
                    text: "Notifications"
                }

                Chip {
                    text: "Do not disturb"
                    on: Notifications.doNotDisturb
                    onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
                }

                Chip {
                    visible: Notifications.count > 0
                    text: "Clear all"
                    onClicked: Notifications.clearAll()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                visible: Notifications.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: "\u{F009B}  Nothing new"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }

            ListView {
                id: list

                Layout.fillWidth: true
                // Grows with its entries up to two thirds of the screen, then scrolls.
                Layout.preferredHeight: Math.min(contentHeight, (window.screen?.height ?? 900) * 0.66)
                visible: Notifications.count > 0
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: Notifications.all
                }

                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: list.width
                }
            }
        }
    }
}
