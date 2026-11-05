// A one-line text box, framed like the search box (SearchField.qml): a
// placeholder while empty, the accent around it while typing. Enter says
// `accepted`; Escape empties it (or goes on to close the card or panel when
// already empty).
import QtQuick
import qs

Rectangle {
    id: box

    property string placeholder: ""
    property alias text: input.text
    property alias validator: input.validator
    property alias inputMask: input.inputMask
    property alias horizontalAlignment: input.horizontalAlignment
    readonly property bool acceptable: input.acceptableInput

    signal accepted()

    function takeFocus(): void {
        input.forceActiveFocus();
    }

    implicitWidth: 200
    implicitHeight: 28
    radius: Theme.moduleRadius
    color: Theme.fg(0.06)
    border.width: 1
    border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.foreground
        selectionColor: Qt.alpha(Theme.accent, 0.55)
        font.family: Theme.font
        font.pixelSize: Theme.rowFontSize
        clip: true

        onAccepted: box.accepted()
        Keys.onEscapePressed: event => {
            if (text === "") {
                event.accepted = false;
                return;
            }
            text = "";
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: input.horizontalAlignment
            visible: input.text === ""
            text: box.placeholder
            color: Theme.fg(Theme.dimOpacity)
            font: input.font
            elide: Text.ElideRight
        }
    }
}
