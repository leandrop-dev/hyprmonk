// A sign at the foot of a scrolling page that there is more below it: the
// page fades out under a small arrow, which scrolls it down when clicked. It
// goes once the end is in view. It puts itself on the Flickable (not on what
// scrolls in it), so it can be declared anywhere, a layout too.
import QtQuick
import qs

Item {
    id: more

    required property Flickable flickable
    readonly property bool shown: flickable.contentHeight - flickable.contentY - flickable.height > 4

    parent: flickable
    z: 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 36
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    // Towards the card's own colour (Theme.card), which is see-through.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha(Theme.background, Theme.cardOpacity) }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: 28
        height: 18
        radius: height / 2
        color: mouse.containsMouse ? Theme.fg(0.2) : Theme.fg(0.1)

        Text {
            anchors.centerIn: parent
            text: "\u{F0140}"  // a chevron down
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                scroll.to = Math.min(more.flickable.contentHeight - more.flickable.height,
                    more.flickable.contentY + more.flickable.height * 0.8);
                scroll.restart();
            }
        }
    }

    NumberAnimation {
        id: scroll

        target: more.flickable
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }
}
