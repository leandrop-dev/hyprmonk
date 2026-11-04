// One app's windows, in a card beside its button (the dock's, or the bar's
// window list): each window's title, marked like the dock's dots (an accent
// pill when focused, hollow when minimised), with a close button. Clicking a
// window brings it, restored if minimised, without moving the pointer.
//
// It opens away from `edge`, the screen edge its button sits on. A popup of
// the dock, so nothing blurs behind it: the card is nearly opaque.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

PopupWindow {
    id: list

    required property Item target
    required property var group
    // The screen edge the target sits on.
    property int edge: Edges.Bottom
    // Room between the target and the card.
    property int gap: 8
    readonly property bool hovered: hover.hovered

    // A window was picked: whoever opened the list may close it.
    signal picked()

    readonly property bool across: edge === Edges.Left || edge === Edges.Right
    readonly property int away: ({ [Edges.Bottom]: Edges.Top, [Edges.Top]: Edges.Bottom,
                                   [Edges.Left]: Edges.Right, [Edges.Right]: Edges.Left })[edge]

    // A thin rect `gap` out from the target's far side, the card growing
    // from it.
    anchor.item: target
    anchor.rect.x: edge === Edges.Left ? target.width + gap - 1 : edge === Edges.Right ? -gap : 0
    anchor.rect.y: edge === Edges.Top ? target.height + gap - 1 : edge === Edges.Bottom ? -gap : 0
    anchor.rect.width: across ? 1 : target.width
    anchor.rect.height: across ? target.height : 1
    anchor.edges: away
    anchor.gravity: away
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    visible: true
    color: "transparent"

    Rectangle {
        id: card

        anchors.fill: parent
        implicitWidth: Math.max(200, column.implicitWidth + 12)
        implicitHeight: column.implicitHeight + 12
        radius: Theme.cardRadius
        color: Qt.alpha(Theme.background, 0.94)
        border.width: 1
        border.color: Theme.rim

        HoverHandler {
            id: hover
        }

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                Layout.leftMargin: 8
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                text: list.group?.name ?? ""
                textFormat: Text.PlainText
                color: Theme.fg(0.6)
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
                font.bold: true
            }

            Repeater {
                model: list.group?.windows ?? []

                Rectangle {
                    id: row

                    required property var modelData
                    readonly property bool hidden: Windows.minimised(modelData)
                    readonly property bool focused: Windows.focused(modelData)

                    Layout.fillWidth: true
                    implicitWidth: line.implicitWidth + 12
                    implicitHeight: 32
                    radius: Theme.moduleRadius
                    color: pick.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

                    MouseArea {
                        id: pick

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Windows.focus(row.modelData);
                            list.picked();
                        }
                    }

                    RowLayout {
                        id: line

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 10

                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: row.focused ? 14 : 6
                            radius: 3
                            color: row.hidden ? "transparent" : row.focused ? Theme.accent : Theme.fg(0.5)
                            border.width: row.hidden ? 1 : 0
                            border.color: Theme.fg(0.5)
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.preferredWidth: Math.min(implicitWidth, 320)
                            text: row.modelData.title || list.group?.name || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: row.hidden ? Theme.fg(0.55) : Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.bodyFontSize
                        }

                        // Close: red on hover, as the title bars' button.
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: Theme.moduleRadius
                            color: shut.containsMouse ? "#c42b1c" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\u{F0156}"
                                color: shut.containsMouse ? "white" : Theme.fg(0.6)
                                font.family: Theme.font
                                font.pixelSize: Theme.bodyFontSize
                            }

                            MouseArea {
                                id: shut

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Windows.close(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
