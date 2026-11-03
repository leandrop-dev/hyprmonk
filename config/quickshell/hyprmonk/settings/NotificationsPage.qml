// Settings > Notifications: how long pop-ups stay, which corner they show in,
// how many show at once and how many the centre keeps
// (services/Notifications.qml). Do not disturb stays in quick actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    readonly property var corners: ({
        "top-right": "Top right",
        "top-left": "Top left",
        "bottom-right": "Bottom right",
        "bottom-left": "Bottom left"
    })

    spacing: 8

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    component Choices: Flow {
        id: choices

        property string key: ""
        property var label: value => String(value)

        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 6

        Repeater {
            model: Notifications.choices[choices.key]

            Chip {
                required property var modelData

                text: choices.label(modelData)
                on: modelData === Notifications.chosen(choices.key)
                onClicked: Notifications.set(choices.key, modelData)
            }
        }
    }

    SectionLabel {
        text: "Pop-ups stay for"
    }

    Note {
        text: "Unless the sender says otherwise; low ones half as long, urgent ones until dismissed. The pointer over one holds it."
    }

    Choices {
        key: "seconds"
        label: value => value + " s"
    }

    SectionLabel {
        text: "Corner"
    }

    Choices {
        key: "position"
        label: value => page.corners[value]
    }

    SectionLabel {
        text: "Shown at once, at most"
    }

    Choices {
        key: "popupCount"
    }

    SectionLabel {
        text: "The centre keeps"
    }

    Note {
        text: "Older ones go first; urgent ones stay until dismissed."
    }

    Choices {
        key: "history"
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true

        Button {
            text: "Send a test"
            onClicked: Quickshell.execDetached(["notify-send", "--app-name", "Settings",
                                                "Test notification", "This is where they show, and for how long."])
        }

        Item {
            Layout.fillWidth: true
        }

        Button {
            enabled: Notifications.changed
            text: "Back to the defaults"
            onClicked: Notifications.reset()
        }
    }
}
