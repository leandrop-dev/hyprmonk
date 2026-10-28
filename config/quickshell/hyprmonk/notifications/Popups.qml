// New notifications, stacked in the top-right corner under the bar on the
// focused screen, newest on top.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: window

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    // Kept mapped, empty, while a centred card is open: Hyprland hands the
    // keyboard to a window whenever a layer unmaps, even away from a card
    // that holds it (services/Overlays.qml).
    visible: (Notifications.popups.length > 0 && !Notifications.centerOpen) || Overlays.open !== ""

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barGap
        right: Theme.barMargin
    }
    implicitWidth: Theme.notificationWidth
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    mask: Region { item: stack }  // empty, it takes no clicks

    WlrLayershell.namespace: "hyprmonk-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            // ScriptModel keeps the existing cards (and their timers) when one is added.
            model: ScriptModel {
                values: Notifications.popups
            }

            NotificationCard {
                id: popup

                required property var modelData

                notification: modelData
                popup: true
                width: stack.width
                onTimedOut: Notifications.popupTimedOut(notification)

                // Slide in from the right edge.
                transform: Translate {
                    id: slide
                    x: Theme.notificationWidth
                }
                opacity: 0
                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popup; property: "opacity"; to: 1; duration: 180 }
                }
            }
        }
    }
}
