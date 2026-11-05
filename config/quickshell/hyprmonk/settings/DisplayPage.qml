// Settings > Display, in three sub-pages:
// - Screens (services/Display.qml): where each screen sits, which is the main
//   one, and the resolution, refresh rate and scale of one. Nothing changes
//   until applied; then it goes back by itself unless kept. Picking and
//   applying again during that still goes back to where it started.
// - Brightness (services/Brightness.qml): each screen's own brightness and
//   contrast, through DDC/CI, and dimming on top for every screen.
// - Night light (services/NightLight.qml): warmer colours off, between set
//   times or always, and how warm.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    // The sub-page shown (SettingsCard.qml): screens, brightness or night.
    property string section: "screens"

    spacing: 8

    Component.onCompleted: {
        Display.refresh();
        Brightness.refresh();
    }
    Component.onDestruction: Display.clearChoice()

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(0.6)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    RowLayout {
        Layout.fillWidth: true
        visible: page.section === "screens" && Display.monitors.length > 1

        SectionLabel {
            Layout.fillWidth: true
            text: "Screens"
        }

        // The one quick actions' Mirror and Main screen only keep.
        Chip {
            text: "Main screen"
            on: Display.monitor?.name === Display.mainScreen
            onClicked: if (Display.monitor) Settings.setMainScreen(Display.monitor.name)
        }
    }

    ScreenMap {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: page.section === "screens" && Display.monitors.length > 1
    }

    SectionLabel {
        visible: page.section === "screens"
        text: "Resolution"
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: page.section === "screens"
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
        visible: page.section === "screens"
        text: "Refresh rate"
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: page.section === "screens"
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
        visible: page.section === "screens"
        text: "Scale"
    }

    Flow {
        Layout.fillWidth: true
        visible: page.section === "screens"
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

    // services/Brightness.qml: each screen's own backlight and contrast, then
    // the dimming on top.
    Repeater {
        model: page.section === "brightness" ? Display.monitors : []

        ColumnLayout {
            id: screen

            required property var modelData
            readonly property var ddc: Brightness.screens[modelData.name]

            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 8

            SectionLabel {
                text: (screen.modelData.model || screen.modelData.name) + " (" + screen.modelData.name + ")"
            }

            SettingSlider {
                Layout.fillWidth: true
                visible: screen.ddc?.brightness !== undefined
                label: "Brightness"
                to: screen.ddc?.brightnessMax ?? 100
                value: screen.ddc?.brightness ?? 0
                onMoved: value => Brightness.set(screen.modelData.name, "brightness", value)
            }

            SettingSlider {
                Layout.fillWidth: true
                visible: screen.ddc?.contrast !== undefined
                label: "Contrast"
                to: screen.ddc?.contrastMax ?? 100
                value: screen.ddc?.contrast ?? 0
                onMoved: value => Brightness.set(screen.modelData.name, "contrast", value)
            }

            Note {
                visible: !screen.ddc
                text: Brightness.reading || !Brightness.read ? "Asking the screen…"
                    : "This screen does not answer over DDC/CI, so its own brightness cannot be set from here. Many monitors have DDC/CI as a switch in their menu."
            }
        }
    }

    SettingSlider {
        Layout.fillWidth: true
        visible: page.section === "brightness"
        label: "Dim further"
        from: Brightness.dimRange.from
        to: Brightness.dimRange.to
        value: Brightness.dim
        shown: Brightness.dim === 100 ? "Off" : Brightness.dim + "%"
        onMoved: value => Brightness.setDim(value)
    }

    Note {
        visible: page.section === "brightness"
        text: "Brightness and contrast are the monitor's own, as its buttons set them, and it keeps them. Dimming further darkens the picture itself, on every screen at once and below the monitor's lowest setting, for late nights; dark scenes lose some detail, so turn the brightness down first."
    }

    // services/NightLight.qml
    RowLayout {
        Layout.fillWidth: true
        visible: page.section === "night"

        SectionLabel {
            Layout.fillWidth: true
            text: "Night light"
        }

        Text {
            text: NightLight.status
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: page.section === "night"
        spacing: 6

        Repeater {
            model: NightLight.modes

            Chip {
                required property string modelData

                text: NightLight.modeLabels[modelData]
                on: modelData === NightLight.mode
                onClicked: NightLight.setMode(modelData)
            }
        }
    }

    // Warmer to the right: fewer kelvin.
    SettingSlider {
        Layout.fillWidth: true
        visible: page.section === "night"
        label: "Warmth"
        from: 0
        to: (NightLight.warmthRange.to - NightLight.warmthRange.from) / 100
        value: (NightLight.warmthRange.to - NightLight.warmth) / 100
        shown: NightLight.warmth + " K"
        onMoved: value => NightLight.setWarmth(NightLight.warmthRange.to - value * 100)
    }

    // In quarter hours.
    SettingSlider {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: page.section === "night"
        enabled: NightLight.mode === "scheduled"
        opacity: enabled ? 1 : Theme.dimOpacity
        label: "Starts at"
        from: 0
        to: 95
        value: Math.round(NightLight.from / 15)
        shown: NightLight.clock(NightLight.from)
        onMoved: value => NightLight.setFrom(Math.round(value) * 15)
    }

    SettingSlider {
        Layout.fillWidth: true
        visible: page.section === "night"
        enabled: NightLight.mode === "scheduled"
        opacity: enabled ? 1 : Theme.dimOpacity
        label: "Ends at"
        from: 0
        to: 95
        value: Math.round(NightLight.to / 15)
        shown: NightLight.clock(NightLight.to)
        onMoved: value => NightLight.setTo(Math.round(value) * 15)
    }

    Note {
        visible: page.section === "night"
        text: "Less blue light in the evening, which is easier on the eyes and on sleep. Between set times it fades in over half an hour from the start, and out over the half hour before the end. The warmth shows at once while it is on."
    }

    // How warm for what (NightLight.guide); a row picks its warmth, the
    // nearest one marked.
    SectionLabel {
        Layout.topMargin: 12
        visible: page.section === "night"
        text: "How warm"
    }

    Repeater {
        model: page.section === "night" ? NightLight.guide : []

        Rectangle {
            id: row

            required property var modelData
            readonly property bool nearest: NightLight.guide.every(other =>
                Math.abs(other.kelvin - NightLight.warmth) >= Math.abs(modelData.kelvin - NightLight.warmth))

            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.moduleRadius
            color: nearest ? Qt.alpha(Theme.accent, 0.55)
                 : mouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    Layout.preferredWidth: 56
                    text: row.modelData.kelvin + " K"
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    font.features: { "tnum": 1 }
                }

                Text {
                    Layout.preferredWidth: 130
                    text: row.modelData.name
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                }

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.use
                    elide: Text.ElideRight
                    color: Theme.fg(0.6)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sounds.play("click", false);
                    NightLight.setWarmth(row.modelData.kelvin);
                }
            }
        }
    }

    Note {
        visible: page.section === "night"
        text: "Warmer is not dimmer: in a dark room, turning the brightness down does more for the eyes than warmth alone."
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true
        visible: page.section === "screens"
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
