// A button with a label: a dim fill, or the accent for the main action.
import QtQuick
import qs

Rectangle {
    id: button

    property string text: ""
    property bool primary: false

    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: Theme.moduleRadius
    opacity: enabled ? 1 : 0.5
    color: primary ? Qt.alpha(Theme.accent, mouse.containsMouse ? 0.7 : 0.55)
                   : Theme.fg(mouse.containsMouse ? 0.16 : 0.08)
    border.width: primary ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.8)

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 12)
        horizontalAlignment: Text.AlignHCenter
        text: button.text
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
