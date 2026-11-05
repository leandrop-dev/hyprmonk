// Settings > Power: how long idle until the screen locks and the screens go
// off (services/Idle.qml). It always locks before a suspend.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    function minutes(value: int): string {
        if (value === 0) return I18n.tr("Never");
        if (value % 60 === 0) return value / 60 + (value === 60 ? " hour" : " hours");
        return value + " min";
    }

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
        property int current: 0

        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 6

        Repeater {
            model: Idle.choices[choices.key]

            Chip {
                required property int modelData

                text: page.minutes(modelData)
                on: modelData === choices.current
                onClicked: Idle.set(choices.key, modelData)
            }
        }
    }

    SectionLabel {
        text: I18n.tr("Lock the screen after")
    }

    Choices {
        key: "lockAfter"
        current: Idle.lockAfter
    }

    SectionLabel {
        text: I18n.tr("Turn the screens off")
    }

    Note {
        text: Idle.lockAfter ? I18n.tr("This long after the lock.") : I18n.tr("This long idle, since it never locks.")
    }

    Choices {
        key: "screensOff"
        current: Idle.screensOff
    }

    Note {
        text: I18n.tr("It always locks before a suspend.")
    }

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Idle.changed
        text: I18n.tr("Back to the defaults")
        onClicked: Idle.reset()
    }
}
