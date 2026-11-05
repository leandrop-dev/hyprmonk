// Settings > Dock (dock/Dock.qml): whether it shows and where, whose
// windows it lists, its size, when it hides, icons growing under the
// pointer, and the dots. Each change shows at once.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 8

    component Row: RowLayout {
        property alias text: label.text

        Layout.fillWidth: true
        spacing: 6

        Text {
            id: label
            Layout.fillWidth: true
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
            elide: Text.ElideRight
        }
    }

    // A chip for each of a choice's values.
    component Choice: Repeater {
        id: choice

        property string key: ""
        property var labels: ({})

        model: Settings.dockChoices[key]

        Chip {
            required property var modelData

            text: choice.labels[modelData] ?? String(modelData)
            on: modelData === Settings.dockChoice(choice.key)
            onClicked: Settings.setDockChoice(choice.key, modelData)
        }
    }

    component Switch: Chip {
        property string key: ""

        text: Settings.dockChoice(key) ? "on" : "off"
        on: Settings.dockChoice(key)
        onClicked: Settings.setDockChoice(key, !Settings.dockChoice(key))
    }

    // The options scroll; the button stays below them.
    Flickable {
        id: flick

        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 8

            SectionLabel {
                text: "Dock"
            }

            Row {
                text: "Show the dock"

                Switch {
                    key: "shown"
                }
            }

            Row {
                text: "Position"

                Choice {
                    key: "position"
                    labels: ({ bottom: "Bottom", top: "Top", left: "Left", right: "Right" })
                }
            }

            Row {
                text: "Windows from"

                Choice {
                    key: "scope"
                    labels: ({ all: "Every workspace", workspace: "This workspace" })
                }
            }

            SettingSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                label: "Size"
                from: Settings.dockSizeRange.from
                to: Settings.dockSizeRange.to
                value: Settings.dockSize
                onMoved: value => Settings.setDockSize(value)
            }

            SectionLabel {
                text: "Behaviour"
            }

            Row {
                text: "Hide"

                Choice {
                    key: "autohide"
                    labels: ({ off: "Never", touch: "When a window touches it", always: "Always" })
                }
            }

            Row {
                text: "Grow under the pointer"

                Switch {
                    key: "magnify"
                }
            }

            Row {
                text: "A dot per window"

                Switch {
                    key: "dots"
                }
            }
        }
    }

    MoreBelow {
        flickable: flick
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.dockChanged
        text: "Back to the defaults"
        onClicked: Settings.resetDock()
    }
}
