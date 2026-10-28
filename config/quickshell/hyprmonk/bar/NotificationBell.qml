// The bell: a badge with how many notifications are open. Click: the centre.
// Right click: do not disturb.
import QtQuick
import qs
import qs.services

Module {
    id: bell

    readonly property int count: Notifications.count

    interactive: true
    icon: Notifications.doNotDisturb ? "\u{F009B}" : (count > 0 ? "\u{F009A}" : "\u{F009C}")
    dim: count === 0 && !Notifications.doNotDisturb

    onClicked: button => {
        if (button === Qt.RightButton)
            Notifications.doNotDisturb = !Notifications.doNotDisturb;
        else
            Notifications.centerOpen = !Notifications.centerOpen;
    }

    Rectangle {
        visible: bell.count > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 1
        width: Math.max(height, badge.implicitWidth + 6)
        height: 14
        radius: height / 2
        color: Theme.accent

        Text {
            id: badge
            anchors.centerIn: parent
            text: bell.count > 99 ? "99+" : bell.count
            color: Theme.background
            font.family: Theme.font
            font.pixelSize: 9
            font.bold: true
        }
    }
}
