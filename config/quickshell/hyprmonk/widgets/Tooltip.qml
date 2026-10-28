// A tooltip below `target`: the first line of `text` in bold, the rest in
// columns as given (spaces kept). A popup of the bar, so nothing blurs
// behind it: the card is nearly opaque.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

PopupWindow {
    id: tip

    required property Item target
    property string text: ""

    readonly property var lines: text.split("\n")

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    visible: true
    color: "transparent"

    Rectangle {
        id: card

        anchors.fill: parent
        implicitWidth: column.implicitWidth + 24
        implicitHeight: column.implicitHeight + 18
        radius: Theme.moduleRadius + 2
        color: Qt.alpha(Theme.background, 0.94)
        border.width: 1
        border.color: Theme.rim

        ColumnLayout {
            id: column

            anchors.centerIn: parent
            spacing: 4

            Text {
                text: tip.lines[0]
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                font.bold: true
            }

            Text {
                visible: tip.lines.length > 1
                text: tip.lines.slice(1).join("\n")
                textFormat: Text.PlainText
                color: Theme.fg(0.8)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }
        }
    }
}
