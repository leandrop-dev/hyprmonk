// Every notification still open, in the bar's card that holds the bell:
// Super+N or a click on the bell. One app's notifications fold into a group
// (NotificationGroup), shown in full when clicked until the panel closes. Do
// not disturb and clear all at the top. A long list scrolls in the card, as
// any panel does.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.notifications
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    // Groups shown in full, by app.
    property var expanded: ({})

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SectionLabel {
            Layout.fillWidth: true
            text: I18n.tr("Notifications")
        }

        Chip {
            text: I18n.tr("Do not disturb")
            on: Notifications.doNotDisturb
            onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
        }

        Chip {
            visible: Notifications.count > 0
            text: I18n.tr("Clear all")
            onClicked: Notifications.clearAll()
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 16
        Layout.bottomMargin: 16
        visible: Notifications.count === 0
        horizontalAlignment: Text.AlignHCenter
        text: "\u{F009B}  " + I18n.tr("No notifications")
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    Repeater {
        // By app: a group keeps its cards when another changes.
        model: ScriptModel {
            values: Notifications.apps
        }

        NotificationGroup {
            required property string modelData

            Layout.fillWidth: true
            app: modelData
            notifications: Notifications.notificationsOf(modelData)
            expanded: panel.expanded[modelData] === true
            onToggled: {
                const next = Object.assign({}, panel.expanded);
                next[app] = !expanded;
                panel.expanded = next;
            }
        }
    }
}
