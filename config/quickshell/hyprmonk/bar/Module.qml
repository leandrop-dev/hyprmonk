// A bar module: an icon and an optional label (or `contents` of its own),
// with a hover fill and an optional tooltip.
// Emits clicked(button) and scrolled(steps) for modules that react.
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets

Item {
    id: mod

    property string icon: ""
    property int iconSize: Theme.fontSize
    property string label: ""
    property color color: Theme.foreground
    property bool dim: false
    property bool interactive: false
    // Its panel is open: tinted with the accent.
    property bool active: false
    // More items for the row, after the icon and label.
    property alias contents: content.data
    // Shown below after a moment's hover (widgets/Tooltip.qml).
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse
    readonly property bool tooltipShown: tooltipLoader.active

    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: content.implicitWidth + 16
    implicitHeight: Theme.barHeight - Theme.cardPadding * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.moduleRadius
        color: mod.active ? Qt.alpha(Theme.accent, 0.25)
             : mod.interactive && mod.hovered ? Theme.fg(Theme.hoverOpacity) : "transparent"
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6
        opacity: mod.dim ? Theme.dimOpacity : 1

        BarText {
            visible: mod.icon !== ""
            text: mod.icon
            font.pixelSize: mod.iconSize
            color: mod.active ? Theme.accent : mod.color
        }

        BarText {
            visible: mod.label !== ""
            text: mod.label
            color: mod.color
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: mod.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => mod.clicked(event.button)
        onWheel: event => mod.scrolled(event.angleDelta.y > 0 ? 1 : -1)
    }

    Timer {
        id: tooltipDelay
        interval: 500
        running: mod.hovered && mod.tooltip !== ""
        onTriggered: tooltipLoader.active = true
    }

    onHoveredChanged: if (!hovered) tooltipLoader.active = false

    Loader {
        id: tooltipLoader

        active: false
        sourceComponent: Tooltip {
            target: mod
            text: mod.tooltip
        }
    }
}
