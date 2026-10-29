// A list of rows under section headings, for the overlay cards (key guide,
// quick actions): a heading before the first row of each section, the
// picked row (`current`) under a highlight that slides to it, and kept in
// view, its heading too when going up. `model` is [{section, ...}]; the
// card gives a `delegate` for a row and a `heading` for a section's name
// (each with `required property var modelData`), and handles keys and
// hovering itself.
import QtQuick
import qs

Flickable {
    id: list

    property var model: []
    property int current: 0
    property int rowHeight: 42
    property int headingHeight: 26
    property int highlightRadius: 10
    property Component delegate: null
    property Component heading: null
    property string emptyText: "Nothing matches"
    property int emptyFontSize: Theme.fontSize

    // Where each row and heading goes, which rows start a section, and the
    // whole height (one row's when empty, for the "Nothing matches" line).
    function measure(entries: var): var {
        const rows = [], starts = [], headings = [];
        let y = 0;
        entries.forEach((entry, i) => {
            starts.push(i === 0 || entry.section !== entries[i - 1].section);
            if (starts[i]) {
                headings.push({ section: entry.section, y });
                y += headingHeight;
            }
            rows.push(y);
            y += rowHeight;
        });
        return { rows, starts, headings, height: entries.length === 0 ? rowHeight : y };
    }

    readonly property var layout: measure(model)
    readonly property bool picked: current >= 0 && current < model.length
    readonly property real rowY: picked ? layout.rows[current] : 0
    // With its heading, when it is the first of its section.
    readonly property real entryY: picked && layout.starts[current] ? rowY - headingHeight : rowY

    contentHeight: layout.height
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    // Again when the list's height changes: rows can arrive (and move the
    // picked one) before the list has grown to hold them.
    function keepInView(): void {
        if (entryY < contentY) contentY = entryY;
        else if (rowY + rowHeight > contentY + height) contentY = rowY + rowHeight - height;
    }

    onRowYChanged: keepInView()
    onHeightChanged: keepInView()

    // The picked row; slides to the next one.
    Rectangle {
        visible: list.picked
        y: list.rowY
        width: list.width
        height: list.rowHeight
        radius: list.highlightRadius
        color: Theme.selection

        Behavior on y {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    Repeater {
        model: list.layout.headings
        delegate: list.heading

        onItemAdded: (index, item) => {
            item.y = Qt.binding(() => list.layout.headings[index]?.y ?? 0);
            item.width = Qt.binding(() => list.width);
            item.height = Qt.binding(() => list.headingHeight);
        }
    }

    Repeater {
        model: list.model
        delegate: list.delegate

        onItemAdded: (index, item) => {
            item.y = Qt.binding(() => list.layout.rows[index] ?? 0);
            item.width = Qt.binding(() => list.width);
            item.height = Qt.binding(() => list.rowHeight);
        }
    }

    Text {
        visible: list.model.length === 0
        x: 12
        height: list.rowHeight
        verticalAlignment: Text.AlignVCenter
        text: list.emptyText
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: list.emptyFontSize
    }
}
