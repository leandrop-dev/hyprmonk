// A search box whose results open in a list over the page, under the box,
// instead of pushing what is below it down. The list is a Popup, drawn above
// everything in the window, so a scrolling page does not clip it. Up and
// Down move through the results, Enter picks the marked one (or, with none
// marked, says `accepted`), Escape empties the box (or goes on to close the
// card when already empty), and a click elsewhere closes the list until the
// next key. Each result: { text, detail, icon, selected, family }, all but
// text optional, `family` writing it in that font; what else it holds comes
// back with `picked`.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import qs
import qs.services

Rectangle {
    id: box

    property string placeholder: ""
    property var results: []
    property bool busy: false  // still looking
    property string message: ""  // when nothing is found
    property alias text: input.text
    property int current: -1  // the result marked by the keys

    readonly property bool typed: input.text.trim() !== ""
    readonly property bool wanted: typed && (results.length > 0 || busy || message !== "")

    signal picked(var result)
    signal accepted()
    signal focused()  // the box took the keys

    // More above or below in the list: it fades under an arrow.
    component Edge: Item {
        id: edge

        property bool upper: false
        property bool shown: false

        anchors.left: parent.left
        anchors.right: parent.right
        height: 22
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: edge.upper ? Qt.alpha(Theme.background, 0.97) : "transparent" }
                GradientStop { position: 1; color: edge.upper ? "transparent" : Qt.alpha(Theme.background, 0.97) }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: edge.upper ? parent.top : undefined
            anchors.bottom: edge.upper ? undefined : parent.bottom
            text: edge.upper ? "\u{F0143}" : "\u{F0140}"  // chevrons up and down
            color: Theme.fg(0.7)
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }
    }

    function pick(result: var): void {
        picked(result);
        current = -1;
    }

    implicitWidth: 260
    implicitHeight: 30
    radius: Theme.moduleRadius
    color: Theme.fg(0.06)
    border.width: 1
    border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

    onWantedChanged: wanted && input.activeFocus ? popup.open() : popup.close()
    onResultsChanged: current = Math.min(current, results.length - 1)

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.foreground
        selectionColor: Qt.alpha(Theme.accent, 0.55)
        font.family: Theme.font
        font.pixelSize: Theme.rowFontSize
        clip: true

        onActiveFocusChanged: if (activeFocus) box.focused()
        onTextEdited: {
            box.current = -1;
            if (box.wanted) popup.open();
        }
        onAccepted: box.current >= 0 ? box.pick(box.results[box.current]) : box.accepted()
        Keys.onDownPressed: {
            if (!popup.opened && box.wanted) popup.open();
            box.current = Math.min(box.results.length - 1, box.current + 1);
        }
        Keys.onUpPressed: box.current = Math.max(-1, box.current - 1)
        Keys.onEscapePressed: event => {
            if (text === "") {
                event.accepted = false;
                return;
            }
            text = "";
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: box.placeholder
            color: Theme.fg(Theme.dimOpacity)
            font: input.font
        }
    }

    T.Popup {
        id: popup

        y: box.height + 4
        width: Math.max(box.width, 320)
        // Sized by hand, and the background drawn in the content: left to
        // the Popup, the background came out empty and the list showed
        // through to the page.
        height: column.implicitHeight + 8
        padding: 0
        closePolicy: T.Popup.CloseOnPressOutsideParent
        background: null

        contentItem: Rectangle {
            radius: Theme.moduleRadius
            color: Qt.alpha(Theme.background, 0.97)
            border.width: 1
            border.color: Theme.rim

            ColumnLayout {
                id: column

                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(list.contentHeight, 280)
                    visible: box.results.length > 0

                    ListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: box.results
                        currentIndex: box.current
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            implicitHeight: option.implicitHeight
                            radius: Theme.moduleRadius
                            color: index === box.current ? Theme.fg(Theme.hoverOpacity * 2) : "transparent"

                            OptionRow {
                                id: option

                                anchors.fill: parent
                                icon: row.modelData.icon ?? ""
                                text: row.modelData.text
                                detail: row.modelData.detail ?? ""
                                family: row.modelData.family ?? ""
                                selected: row.modelData.selected ?? false
                                onClicked: box.pick(row.modelData)
                            }
                        }
                    }

                    Edge {
                        anchors.top: parent.top
                        upper: true
                        shown: !list.atYBeginning
                    }

                    Edge {
                        anchors.bottom: parent.bottom
                        shown: !list.atYEnd
                    }
                }

                Searching {
                    Layout.leftMargin: 8
                    running: box.busy
                }

                Text {
                    Layout.leftMargin: 8
                    Layout.bottomMargin: 4
                    visible: !box.busy && box.results.length === 0 && box.message !== ""
                    text: box.message
                    color: Theme.fg(0.6)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }
            }
        }
    }
}
