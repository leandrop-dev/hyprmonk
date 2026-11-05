// A reading as a bar it fills, from 0 to 1, with its name and icon at the
// start and its value at the end, inside the bar. The fill slides to each new
// reading, and turns to the warning colour from `warnAt` up.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: bar

    property string icon: ""
    property string label: ""
    property string value: ""
    property real level: 0
    property real warnAt: 2  // never, unless set

    readonly property real shown: isNaN(level) ? 0 : Math.max(0, Math.min(1, level))

    implicitHeight: 28
    radius: Theme.moduleRadius
    color: Theme.fg(0.07)
    clip: true

    Rectangle {
        width: bar.width * bar.shown
        height: parent.height
        radius: parent.radius
        color: Qt.alpha(bar.shown >= bar.warnAt ? Theme.warning : Theme.accent, 0.55)

        Behavior on width {
            NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: 300 }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Text {
            visible: bar.icon !== ""
            text: bar.icon
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Text {
            Layout.fillWidth: true
            text: bar.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
        }

        Text {
            text: bar.value
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
            font.features: { "tnum": 1 }  // figures of one width, so it does not jitter
        }
    }
}
