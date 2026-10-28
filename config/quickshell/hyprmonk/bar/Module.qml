// A bar module: an icon and an optional label, with a hover fill.
// Emits clicked(button) and scrolled(steps) for modules that react.
import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: mod

    property string icon: ""
    property int iconSize: Theme.fontSize
    property string label: ""
    property color color: Theme.foreground
    property bool dim: false
    property bool interactive: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: content.implicitWidth + 16
    implicitHeight: Theme.barHeight - Theme.cardPadding * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.moduleRadius
        color: mod.interactive && mod.hovered ? Theme.fg(Theme.hoverOpacity) : "transparent"
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6
        opacity: mod.dim ? Theme.dimOpacity : 1

        BarText {
            visible: mod.icon !== ""
            text: mod.icon
            font.pixelSize: mod.iconSize
            color: mod.color
        }

        BarText {
            visible: mod.label !== ""
            text: mod.label
            color: mod.color
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: mod.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => mod.clicked(event.button)
        onWheel: event => mod.scrolled(event.angleDelta.y > 0 ? 1 : -1)
    }
}
