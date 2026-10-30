// A small turning ring and "Searching", while a panel looks for what is in
// reach. `running` shows it.
import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: searching

    property bool running: false

    visible: running
    spacing: 6

    Text {
        text: "\u{F0772}"
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.rowFontSize

        RotationAnimator on rotation {
            running: searching.running
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    Text {
        text: "Searching"
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }
}
