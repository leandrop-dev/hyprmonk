// A device or an app with its level: an icon (click to mute), the name and
// percentage, and a slider under them.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs

RowLayout {
    id: row

    property string icon: ""        // a Nerd Font glyph
    property string iconSource: ""  // or an image (an app's own icon)
    property string name: ""
    property real value: 0
    property bool muted: false

    signal moved(real value)
    signal muteToggled()

    spacing: 12

    Item {
        implicitWidth: 18
        implicitHeight: 18

        IconImage {
            anchors.fill: parent
            visible: row.iconSource !== ""
            source: row.iconSource
            opacity: row.muted ? Theme.dimOpacity : 1
        }

        Text {
            anchors.centerIn: parent
            visible: row.iconSource === ""
            text: row.icon
            color: row.muted ? Theme.warning : Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: row.muteToggled()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: row.name
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                elide: Text.ElideRight
            }

            Text {
                text: row.muted ? "Muted" : Math.round(row.value * 100) + "%"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }
        }

        Slider {
            Layout.fillWidth: true
            value: row.value
            dim: row.muted
            onMoved: value => row.moved(value)
        }
    }
}
