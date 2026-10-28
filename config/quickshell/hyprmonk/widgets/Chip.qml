// A small rounded button. With `on` set it is a switch: green while on.
import QtQuick
import qs

Rectangle {
    id: chip

    property string text: ""
    property var on: undefined  // undefined: a plain button

    signal clicked()

    readonly property bool isSwitch: on !== undefined

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 22
    radius: height / 2
    color: isSwitch && on ? Theme.positive : Theme.fg(mouse.containsMouse ? 0.16 : 0.08)

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.isSwitch && chip.on ? Theme.background : Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
