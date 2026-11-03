// Settings > Recording: what a recording and the replay hear, how good they
// look and where they go (services/Recorder.qml). What is recorded, the
// screen, a region or a window, stays in quick actions beside the button.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    property bool refused: false

    function save(): void {
        refused = !Recorder.setFolder(field.text);
        if (!refused) field.focus = false;
    }

    spacing: 8

    component Row: RowLayout {
        property alias text: label.text

        Layout.fillWidth: true

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
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    SectionLabel {
        text: "Sound"
    }

    Row {
        text: "What the system plays"

        Chip {
            text: Recorder.sound ? "on" : "off"
            on: Recorder.sound
            onClicked: Recorder.setSound(!Recorder.sound)
        }
    }

    Row {
        text: "The microphone"

        Chip {
            text: Recorder.microphone ? "on" : "off"
            on: Recorder.microphone
            onClicked: Recorder.setMicrophone(!Recorder.microphone)
        }
    }

    Note {
        visible: Recorder.sound && Recorder.microphone
        text: "Both go into one track, so any player plays them together."
    }

    SectionLabel {
        Layout.topMargin: 12
        text: "Quality"
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: Recorder.qualities

            Chip {
                required property var modelData

                text: modelData.label
                on: modelData.name === Recorder.quality
                onClicked: Recorder.setQuality(modelData.name)
            }
        }
    }

    Note {
        text: "Higher looks better and makes bigger files. Very high is the recorder's own default."
    }

    SectionLabel {
        Layout.topMargin: 12
        text: "Save to"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.moduleRadius
            color: Theme.fg(0.06)
            border.width: 1
            border.color: page.refused ? Theme.warning
                : field.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                selectionColor: Qt.alpha(Theme.accent, 0.55)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                clip: true
                text: Recorder.folder

                onAccepted: page.save()
                onTextEdited: page.refused = false
                // Leaving it unsaved puts back what is kept.
                onActiveFocusChanged: if (!activeFocus) {
                    text = Qt.binding(() => Recorder.folder);
                    page.refused = false;
                }
                Keys.onEscapePressed: event => {
                    if (text === Recorder.folder) {
                        event.accepted = false;
                        return;
                    }
                    text = Qt.binding(() => Recorder.folder);
                    page.refused = false;
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    elide: Text.ElideMiddle
                    visible: !field.text
                    text: Recorder.defaultFolder
                    color: Theme.fg(Theme.dimOpacity)
                    font: field.font
                }
            }
        }

        Chip {
            text: "Open"
            onClicked: Recorder.openFolder()
        }
    }

    Note {
        color: page.refused ? Theme.warning : Theme.fg(Theme.dimOpacity)
        text: page.refused ? "A folder from the top, starting with / or ~/."
            : field.activeFocus && field.text !== Recorder.folder ? "Enter keeps it, Escape puts back the last one."
            : Recorder.folder ? "Emptied, it goes back to " + Recorder.defaultFolder + "."
            : "Type another folder and press Enter to save there instead."
    }

    Note {
        Layout.topMargin: 12
        text: "A change counts from the next recording; a replay that is on keeps what it started with until switched off and on."
    }

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Recorder.changed
        text: "Back to the defaults"
        onClicked: Recorder.reset()
    }
}
