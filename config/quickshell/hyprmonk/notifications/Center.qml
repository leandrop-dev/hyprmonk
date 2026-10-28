// Every notification still open, under the bar's right card: Super+N or a
// click on the bell. One app's notifications fold into a group
// (NotificationGroup). Do not disturb and clear all at the top; a click
// outside or Escape closes it.
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
    implicitWidth: Theme.notificationWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "hyprmonk-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Groups shown in full, by app; folded again when the centre closes.
    property var expanded: ({})

    onVisibleChanged: if (!visible) expanded = ({})

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
                text: "\u{F009B}  No notifications"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }

            ListView {
                id: list

                Layout.fillWidth: true
                // Grows with its entries, then scrolls.
                Layout.preferredHeight: Math.min(contentHeight, Theme.notificationCenterHeight)
                visible: Notifications.count > 0
                clip: true
                spacing: 10
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: Notifications.groups
                }

                delegate: NotificationGroup {
                    required property var modelData

                    width: list.width
                    app: modelData.app
                    notifications: modelData.notifications
                    expanded: window.expanded[modelData.app] === true
                    onToggled: {
                        const next = Object.assign({}, window.expanded);
                        next[app] = !expanded;
                        window.expanded = next;
                    }
                }
            }
        }
    }
}
