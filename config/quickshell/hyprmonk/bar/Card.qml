// One of the bar's cards: a rounded translucent box sized to its modules.
// Given a `panel`, the same card grows down into it (and widens to at least
// `panelWidth`), keeping its modules on top. A panel taller than the bar's
// window has room for scrolls; one with pages (`page`) starts each at the top.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: card

    default property alias modules: row.data
    // The side the card is anchored to: it widens away from it.
    property int side: Qt.AlignHCenter
    // What opens under the modules; null when closed.
    property Component panel: null
    // The least the card widens to while a panel is open.
    property int panelWidth: Theme.barPanelWidth

    // The pointer is over the card: its edge and an open panel too, not only
    // its modules (a handler given to the card would land in its row).
    readonly property alias hovered: hover.hovered

    // The panel being shown; kept while it folds away after `panel` clears.
    property Component shown: null
    property real openness: panel ? 1 : 0

    // What the window leaves a panel, below the modules and above its own margin.
    readonly property real panelRoom: (parent?.height ?? 0) - Theme.barGap * 2 - Theme.barHeight - 18
    readonly property var page: loader.item?.page ?? null

    onPanelChanged: if (panel) shown = panel
    onOpennessChanged: if (openness === 0 && !panel) shown = null
    onShownChanged: scroller.contentY = 0
    onPageChanged: scroller.contentY = 0

    Behavior on openness {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    readonly property real baseWidth: row.implicitWidth + Theme.cardPadding * 2
    readonly property real fullWidth: Math.max(baseWidth, panelWidth)

    implicitWidth: baseWidth + (fullWidth - baseWidth) * openness
    implicitHeight: Theme.barHeight + (scroller.height + 18) * openness
    radius: Theme.cardRadius
    color: Theme.card
    border.width: 1
    border.color: Theme.rim
    clip: true

    HoverHandler {
        id: hover
    }

    RowLayout {
        id: row

        x: card.side === Qt.AlignRight ? card.width - width - Theme.cardPadding
         : card.side === Qt.AlignLeft ? Theme.cardPadding
         : (card.width - width) / 2
        y: (Theme.barHeight - height) / 2
        spacing: 2
    }

    // 18 px from the card's edges, as in HyprFlow.
    Flickable {
        id: scroller

        readonly property bool overflows: loader.implicitHeight > card.panelRoom

        x: 18
        y: Theme.barHeight + 6
        width: card.fullWidth - 36
        height: Math.min(loader.implicitHeight, card.panelRoom)
        contentWidth: width
        contentHeight: loader.implicitHeight
        interactive: overflows
        clip: overflows
        boundsBehavior: Flickable.StopAtBounds
        opacity: card.openness

        // A panel that shrinks (a list emptied) must not leave it past its end.
        onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))

        Loader {
            id: loader

            width: scroller.width
            sourceComponent: card.shown
        }
    }

    // How far down it is.
    Rectangle {
        visible: scroller.overflows && card.openness > 0
        x: scroller.x + scroller.width + 7
        y: scroller.y + scroller.visibleArea.yPosition * scroller.height
        width: 3
        height: scroller.visibleArea.heightRatio * scroller.height
        radius: 1.5
        color: Theme.fg(0.25)
    }
}
