// New notifications, stacked in a corner of the focused screen, top right
// under the bar to begin with (Settings > Notifications); the newest nearest
// the corner.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.widgets
import qs.services

PanelWindow {
    id: window

    readonly property bool atTop: Notifications.position.startsWith("top")
    readonly property bool onLeft: Notifications.position.endsWith("left")

    screen: Overlays.popupScreen
    // Kept mapped, empty, while a centred card is open: Hyprland hands the
    // keyboard to a window whenever a layer unmaps, even away from a card
    // that holds it (services/Overlays.qml).
    visible: (Notifications.popups.length > 0 && !Notifications.centerOpen) || Overlays.open !== ""

    anchors {
        top: window.atTop
        bottom: !window.atTop
        left: window.onLeft
        right: !window.onLeft
    }
    margins {
        top: Theme.barGap
        bottom: Theme.barMargin
        left: Theme.barMargin
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
                values: window.atTop ? Notifications.popups : Notifications.popups.slice().reverse()
            }

            NotificationCard {
                id: popup

                required property var modelData

                notification: modelData
                popup: true
                width: stack.width
                onTimedOut: Notifications.popupTimedOut(notification)

                // Slide in from the screen's edge.
                transform: Translate {
                    id: slide
                    x: window.onLeft ? -Theme.notificationWidth : Theme.notificationWidth
                }
                opacity: 0
                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    CardAnimation { target: slide; property: "x"; to: 0 }
                    CardAnimation { target: popup; property: "opacity"; to: 1 }
                }
            }
        }
    }
}
