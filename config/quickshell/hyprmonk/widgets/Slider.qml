// A level from 0 to 1: click or drag along it, or scroll over it. It shows
// `value` and emits moved(value) for the owner to apply.
import QtQuick
import qs

Item {
    id: slider

    property real value: 0
    property bool dim: false

    signal moved(real value)

    implicitHeight: 16
    opacity: dim ? Theme.dimOpacity : 1

    readonly property real shown: Math.max(0, Math.min(1, value))

    function moveTo(x: real): void {
        moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Theme.fg(0.15)

        Rectangle {
            width: track.width * slider.shown
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(slider.width - width, track.width * slider.shown - width / 2))
        width: 12
        height: 12
        radius: 6
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: event => slider.moveTo(event.x)
        onPositionChanged: event => { if (pressed) slider.moveTo(event.x); }
        onWheel: event => slider.moved(Math.max(0, Math.min(1, slider.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
