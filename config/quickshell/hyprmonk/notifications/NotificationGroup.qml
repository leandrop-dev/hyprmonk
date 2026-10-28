// One app's notifications in the centre. A single one is a plain card. Two
// or more get a header (the app, how many, Show all, × to clear them) and
// fold to the newest card with the edges of the rest behind it; Show all
// (or a click on those edges) lists every one.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: group

    required property string app
    required property var notifications  // newest first
    property bool expanded: false

    signal toggled()

    readonly property bool single: notifications.length === 1
    // The card always shown; the rest only when expanded.
    readonly property var shown: single || expanded ? notifications : notifications.slice(0, 1)
    // Edges drawn behind a folded group, at most two.
    readonly property int edges: single || expanded ? 0 : Math.min(2, notifications.length - 1)

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: !group.single
        spacing: 8

        SectionLabel {
            Layout.fillWidth: true
            text: group.app
            elide: Text.ElideRight
        }

        Text {
            text: group.notifications.length
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }

        Chip {
            text: group.expanded ? "Show less" : "Show all"
            onClicked: group.toggled()
        }

        Chip {
            text: "\u{F0156}"
            onClicked: {
                for (const notification of group.notifications.slice())
                    notification.dismiss();
            }
        }
    }

    Repeater {
        model: group.shown

        NotificationCard {
            required property Notification modelData

            Layout.fillWidth: true
            notification: modelData
            // The header names the app already.
            showApp: group.single
        }
    }

    // The folded ones, as card edges peeking out below.
    Item {
        Layout.fillWidth: true
        Layout.topMargin: -6
        visible: group.edges > 0
        implicitHeight: group.edges * 5

        Repeater {
            model: group.edges

            Rectangle {
                required property int index

                x: (index + 1) * 10
                y: index * 5
                width: parent.width - x * 2
                height: 5
                radius: 3
                color: Theme.fg(0.12 - index * 0.04)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: group.toggled()
        }
    }
}
