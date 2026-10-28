// One choice in a list: an icon and a name. The selected one is filled with
// the accent.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: option

    property string icon: ""
    property string text: ""
    property bool selected: false

    signal clicked()

    implicitHeight: 30
    radius: Theme.moduleRadius
    color: selected ? Qt.alpha(Theme.accent, 0.55)
         : mouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        Text {
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignHCenter
            text: option.icon
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Text {
            Layout.fillWidth: true
            text: option.text
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
            font.bold: option.selected
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: option.clicked()
    }
}
