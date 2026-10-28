// A level from 0 to 1 that is only shown, not set: a thin bar.
import QtQuick
import qs

Rectangle {
    id: meter

    property real value: 0
    property color fill: Theme.accent

    implicitHeight: 4
    radius: 2
    color: Theme.fg(0.15)

    Rectangle {
        width: meter.width * Math.max(0, Math.min(1, meter.value))
        height: parent.height
        radius: parent.radius
        color: meter.fill
    }
}
