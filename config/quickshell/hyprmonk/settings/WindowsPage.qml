// Settings > Windows: gaps, borders and blur, applied as they move; how
// windows tile, shadows, and animations and their speed. Game mode holds
// shadows and animations off while on.
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

        model: Settings.windowChoices[key]

        Chip {
            required property var modelData

            text: choice.labels[modelData] ?? String(modelData)
            on: modelData === Settings.windowChoice(choice.key)
            onClicked: Settings.setWindowChoice(choice.key, modelData)
        }
    }

    component Switch: Chip {
        property string key: ""

        text: Settings.windowChoice(key) ? "on" : "off"
        on: Settings.windowChoice(key)
        onClicked: Settings.setWindowChoice(key, !Settings.windowChoice(key))
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

            Repeater {
                model: ["Gaps", "Borders", "Blur"]

                ColumnLayout {
                    id: group

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 6

                    SectionLabel {
                        text: group.modelData
                    }

                    Repeater {
                        model: Settings.windowOptions.filter(option => option.group === group.modelData)

                        SettingSlider {
                            required property var modelData

                            Layout.fillWidth: true
                            label: modelData.label
                            from: modelData.from
                            to: modelData.to
                            value: Settings.windowValue(modelData)
                            onMoved: value => Settings.setWindow(modelData, value)
                        }
                    }
                }
            }

            SectionLabel {
                text: "Tiling and motion"
            }

            Row {
                text: "Layout"

                Choice {
                    key: "layout"
                    labels: ({ dwindle: "Dwindle", master: "Master", scrolling: "Scrolling", floating: "Floating" })
                }
            }

            Row {
                text: "Shadows"

                Switch {
                    key: "shadows"
                }
            }

            Row {
                text: "Animations"

                Choice {
                    key: "animationSpeed"
                    labels: ({ normal: "Normal", fast: "Fast", slow: "Slow" })
                }

                Switch {
                    key: "animations"
                }
            }
        }
    }

    MoreBelow {
        flickable: flick
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.windowChanged
        text: "Back to the defaults"
        onClicked: Settings.resetWindow()
    }
}
