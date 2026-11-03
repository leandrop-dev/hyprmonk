// A whole number in a range: its name and value, and a slider under them.
// `shown`, when set, is written in place of the number and its unit.
import QtQuick
import QtQuick.Layouts
import qs

ColumnLayout {
    id: row

    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property string unit: ""
    property string shown: ""

    signal moved(real value)

    spacing: 2

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: row.label
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Text {
            text: row.shown || row.value + row.unit
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }
    }

    Slider {
        Layout.fillWidth: true
        value: (row.value - row.from) / (row.to - row.from)
        step: 1 / (row.to - row.from)
        onMoved: value => row.moved(row.from + value * (row.to - row.from))
    }
}
