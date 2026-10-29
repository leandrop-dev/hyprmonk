// The battery panel, under the bar's batteries: each device with its icon,
// name, level and whether it is charging.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    spacing: 12

    Component.onCompleted: Battery.refresh()

    SectionLabel {
        text: "Batteries"
    }

    Text {
        Layout.fillWidth: true
        visible: Battery.devices.length === 0
        text: "No batteries"
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    Repeater {
        // ScriptModel keeps a device's row when another comes or goes.
        model: ScriptModel {
            values: Battery.keys
        }

        RowLayout {
            id: row

            required property string modelData
            readonly property var device: Battery.device(modelData)
            readonly property bool low: Battery.isLow(device)

            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 18
                horizontalAlignment: Text.AlignHCenter
                text: row.device.icon
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: row.device.name
                        textFormat: Text.PlainText
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.rowFontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: row.device.charging
                        text: "\u{F140B} charging"
                        color: Theme.fg(Theme.dimOpacity)
                        font.family: Theme.font
                        font.pixelSize: Theme.smallFontSize
                    }

                    Text {
                        text: row.device.percent + "%"
                        color: row.low ? Theme.warning : Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.rowFontSize
                        font.bold: true
                    }
                }

                Meter {
                    Layout.fillWidth: true
                    value: row.device.percent / 100
                    fill: row.low ? Theme.warning : Theme.accent
                }
            }
        }
    }
}
