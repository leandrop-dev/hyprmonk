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

        text: Settings.windowChoice(key) ? I18n.tr("on") : I18n.tr("off")
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
                model: [I18n.mark("Gaps"), I18n.mark("Borders"), I18n.mark("Blur")]

                ColumnLayout {
                    id: group

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 6

                    SectionLabel {
                        text: I18n.tr(group.modelData)
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
                text: I18n.tr("Tiling and motion")
            }

            Row {
                text: I18n.tr("Layout")

                Choice {
                    key: "layout"
                    labels: ({ dwindle: I18n.tr("Dwindle"), master: I18n.tr("Master"), scrolling: I18n.tr("Scrolling"), floating: I18n.tr("Floating") })
                }
            }

            Row {
                text: I18n.tr("Shadows")

                Switch {
                    key: "shadows"
                }
            }

            Row {
                text: I18n.tr("Animations")

                Choice {
                    key: "animationSpeed"
                    labels: ({ normal: I18n.tr("Normal"), fast: I18n.tr("Fast"), slow: I18n.tr("Slow") })
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
        text: I18n.tr("Back to the defaults")
        onClicked: Settings.resetWindow()
    }
}
