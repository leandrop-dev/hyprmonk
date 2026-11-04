// A choice shown as a small picture with its name under it (Settings): the
// chosen one ringed and named in the accent. What it shows goes inside, over
// `fill`, clipped to its rounded corners. `hovered` serves choices previewed
// while the pointer is on them.
import QtQuick
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: card

    property string label: ""
    property bool chosen: false
    property color fill: Theme.fg(0.05)
    default property alias content: frame.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    width: 112
    height: frame.height + 22

    ClippingRectangle {
        id: frame

        width: parent.width
        height: 62
        radius: Theme.moduleRadius
        color: card.fill
    }

    // Over the picture, so it is not hidden under it.
    Rectangle {
        anchors.fill: frame
        radius: frame.radius
        color: "transparent"
        border.width: card.chosen ? 2 : 1
        border.color: card.chosen ? Theme.accent : card.hovered ? Theme.fg(0.45) : Theme.rim
    }

    Text {
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: card.label
        color: card.chosen ? Theme.accent : Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sounds.play("click", false);
            card.clicked();
        }
    }
}
