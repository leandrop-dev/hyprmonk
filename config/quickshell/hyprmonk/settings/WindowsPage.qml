// Settings > Windows: gaps, borders and blur, applied as they move.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 8

    Repeater {
        model: ["Gaps", "Borders", "Blur"]

        ColumnLayout {
            id: group

            required property string modelData

            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 10

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

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.windowChanged
        text: "Back to the defaults"
        onClicked: Settings.resetWindow()
    }
}
