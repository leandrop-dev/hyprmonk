// The media panel's lyrics (services/Lyrics.qml), in place of the track:
// synced ones scroll by themselves, the line being sung bright in the middle
// and the others faded; plain ones (no timing) scroll by hand. Otherwise a
// word on why there are none.
import QtQuick
import QtQuick.Effects
import qs
import qs.services

Item {
    id: view

    readonly property bool synced: Lyrics.status === "synced"

    clip: true

    // Lines fade out at the top and bottom edges instead of being cut.
    layer.enabled: synced
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: fade
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        id: fade

        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.3; color: "white" }
            GradientStop { position: 0.7; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    ListView {
        id: list

        anchors.fill: parent
        visible: Lyrics.status === "synced" || Lyrics.status === "plain"
        model: Lyrics.lines
        spacing: 4
        interactive: !view.synced
        boundsBehavior: Flickable.StopAtBounds

        // Synced: the current line held in the middle. New lyrics put the
        // view's own index back to 0 (a new model), so it is bound again.
        readonly property int line: view.synced ? Math.max(0, Lyrics.index) : -1
        currentIndex: line
        onModelChanged: currentIndex = Qt.binding(() => line)
        highlightRangeMode: view.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - 12
        preferredHighlightEnd: height / 2 + 12
        highlightMoveDuration: 300
        highlightFollowsCurrentItem: true

        delegate: Text {
            required property var modelData
            required property int index

            readonly property bool current: view.synced && index === Lyrics.index

            width: list.width
            text: modelData.text
            textFormat: Text.PlainText
            color: current ? Theme.foreground : Theme.fg(view.synced ? 0.4 : 0.7)
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
            font.bold: current
            wrapMode: Text.WordWrap
            maximumLineCount: view.synced ? 2 : 4
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !list.visible
        text: ({
            loading: "Looking for lyrics…",
            instrumental: "♪  Instrumental",
            none: "No lyrics found",
            error: "Lyrics unavailable right now"
        })[Lyrics.status] ?? ""
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }
}
