// Settings > Tone: the saved tone's cards and text, kept with that tone. Only
// colours that read on its background are offered or taken.
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets

ColumnLayout {
    id: page

    readonly property var tone: Theme.toneOf(Theme.savedTone)
    readonly property string colour: String(tone.foreground).toLowerCase()
    readonly property var swatches: {
        const own = String(Theme.baseTone(Theme.savedTone).foreground).toLowerCase();
        const others = tone.light
            ? ["#000000", "#1f1f1f", "#3a3a3a", "#4a3a28", "#1e3a5f", "#234d2f"]
            : ["#ffffff", "#e8e6e3", "#d4d4d8", "#f5e6c8", "#cfe3ff", "#c8f0d0"];
        return [own].concat(others.filter(shade => shade !== own && Theme.readable(shade)));
    }

    function typed(text: string): void {
        if (/^#[0-9a-f]{6}$/i.test(text) && Theme.readable(text)) Theme.setTextColour(text);
    }

    spacing: 8

    onColourChanged: field.text = colour

    SectionLabel {
        Layout.bottomMargin: 2
        text: Theme.tones[Theme.savedTone].label
    }

    Text {
        Layout.bottomMargin: 12
        text: "Changes stay with this tone."
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    SectionLabel {
        text: "Cards"
    }

    SettingSlider {
        Layout.fillWidth: true
        Layout.topMargin: 2
        label: "Opacity"
        from: 30
        to: 100
        unit: "%"
        value: Math.round(Theme.cardOpacity * 100)
        onMoved: value => Theme.setCardOpacity(Math.round(value) / 100)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 12

        Text {
            Layout.fillWidth: true
            text: "Blur behind them"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Chip {
            text: Theme.cardBlur ? "on" : "off"
            on: Theme.cardBlur
            onClicked: Theme.setCardBlur(!Theme.cardBlur)
        }
    }

    SectionLabel {
        text: "Text"
    }

    RowLayout {
        Layout.topMargin: 2
        spacing: 8

        Repeater {
            model: page.swatches

            Rectangle {
                id: swatch

                required property string modelData

                implicitWidth: 34
                implicitHeight: 34
                radius: Theme.moduleRadius
                color: page.tone.background
                border.width: modelData === page.colour ? 2 : 1
                border.color: modelData === page.colour ? Theme.accent : Theme.rim

                Text {
                    anchors.centerIn: parent
                    text: "A"
                    color: swatch.modelData
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Theme.setTextColour(swatch.modelData)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 12

        Rectangle {
            implicitWidth: 110
            implicitHeight: 30
            radius: Theme.moduleRadius
            color: Theme.fg(0.06)
            border.width: 1
            border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: page.colour
                maximumLength: 7
                color: Theme.foreground
                selectionColor: Qt.alpha(Theme.accent, 0.55)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                clip: true

                onTextEdited: page.typed(text)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: /^#[0-9a-f]{6}$/i.test(field.text) && !Theme.readable(field.text)
            text: "Too close to the background"
            color: Theme.warning
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
        }
    }

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Theme.toneAdjusted
        text: "Back to the defaults"
        onClicked: Theme.resetTone()
    }
}
