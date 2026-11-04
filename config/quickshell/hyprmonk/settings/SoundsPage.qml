// Settings > Sounds (services/Sounds.qml): the interface's sounds on or off,
// the set they come from, their volume and the notification tone, with a
// chip to hear each one. Each change shows at once.
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

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(0.6)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    // The options scroll; the button stays below them.
    Flickable {
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
                text: "Sounds"
            }

            Row {
                text: "Play sounds"

                Chip {
                    text: Sounds.on ? "on" : "off"
                    on: Sounds.on
                    onClicked: Settings.setSoundChoice("on", !Sounds.on)
                }
            }

            Note {
                text: "Quiet in game mode and do not disturb, except for urgent notifications."
            }

            Row {
                text: "Set"

                Repeater {
                    model: Settings.soundChoices.set

                    Chip {
                        required property string modelData

                        text: ({ hyprmonk: "hyprmonk", serpantinum: "Serpantinum" })[modelData]
                        on: modelData === Sounds.set
                        onClicked: Settings.setSoundChoice("set", modelData)
                    }
                }
            }

            SettingSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                label: "Volume"
                unit: "%"
                from: Settings.soundVolumeRange.from
                to: Settings.soundVolumeRange.to
                value: Settings.soundVolume
                onMoved: value => Settings.setSoundVolume(value)
            }

            SectionLabel {
                text: "Notification tone"
            }

            // Picking one plays it.
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Settings.soundChoices.tone

                    Chip {
                        required property string modelData

                        text: ({ set: "The set's own", chime: "hyprmonk chime" })[modelData] ?? modelData
                        on: modelData === Sounds.tone
                        sounds: false
                        onClicked: {
                            Settings.setSoundChoice("tone", modelData);
                            Sounds.preview("notify");
                        }
                    }
                }
            }

            SectionLabel {
                text: "Hear them"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { kind: "click", label: "Click" },
                        { kind: "on", label: "Switch on" },
                        { kind: "off", label: "Switch off" },
                        { kind: "open", label: "Card opens" },
                        { kind: "close", label: "Card closes" },
                        { kind: "notify", label: "Notification" },
                        { kind: "connect", label: "Connected" },
                        { kind: "disconnect", label: "Disconnected" }
                    ]

                    Chip {
                        required property var modelData

                        text: modelData.label
                        sounds: false
                        onClicked: Sounds.preview(modelData.kind)
                    }
                }
            }
        }
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.soundsChanged
        text: "Back to the defaults"
        onClicked: Settings.resetSounds()
    }
}
