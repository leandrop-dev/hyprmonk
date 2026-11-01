// Settings > Display: resolution, refresh rate and scale of a screen. Nothing
// changes until applied; then it goes back by itself unless kept. Picking and
// applying again during that still goes back to where it started
// (services/Display.qml).
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    spacing: 8

    Component.onCompleted: Display.refresh()
    Component.onDestruction: Display.clearChoice()

    SectionLabel {
        visible: Display.monitors.length > 1
        text: "Screen"
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: Display.monitors.length > 1
        spacing: 6

        Repeater {
            model: Display.monitors

            Chip {
                required property var modelData

                text: modelData.name
                on: modelData.name === Display.monitor?.name
                onClicked: {
                    if (Display.trying) return;
                    Display.clearChoice();
                    Display.picked = modelData.name;
                }
            }
        }
    }

    SectionLabel {
        text: "Resolution"
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 6

        Repeater {
            model: Display.resolutions

            Chip {
                required property string modelData

                text: modelData
                on: modelData === Display.shownResolution
                onClicked: {
                    Display.chosenResolution = modelData;
                    Display.chosenRate = 0;
                }
            }
        }
    }

    SectionLabel {
        text: "Refresh rate"
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 6

        Repeater {
            model: Display.rates

            Chip {
                required property real modelData

                text: modelData + " Hz"
                on: modelData === Display.shownRate
                onClicked: Display.chosenRate = modelData
            }
        }
    }

    SectionLabel {
        text: "Scale"
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: Display.scales

            Chip {
                required property real modelData

                text: modelData * 100 + "%"
                on: modelData === Display.shownScale
                onClicked: Display.chosenScale = modelData
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: Display.trying ? "Keep this? Going back in " + Display.left + " s"
                : Display.changed ? "Nothing changes until applied" : ""
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Button {
            visible: Display.trying
            text: "Go back"
            onClicked: Display.goBack()
        }

        Button {
            visible: Display.changed
            primary: true
            text: "Apply"
            onClicked: Display.tryChoice()
        }

        Button {
            visible: Display.trying && !Display.changed
            primary: true
            text: "Keep"
            onClicked: Display.keep()
        }

        Button {
            visible: !Display.trying && !Display.changed
            enabled: Settings.displayKept(Display.monitor?.name ?? "")
            text: "Back to the defaults"
            onClicked: Display.resetScreen()
        }
    }
}
