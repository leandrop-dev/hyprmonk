// One app in the dock: its icon, and a dot per window (up to three) along
// the edge side: hollow for a minimised window, an accent pill for the
// focused one. An app whose windows are all minimised is faded.
//
// Left click: Windows.activate (focus, cycle, minimise the focused one).
// Middle click: a new window. Hovering lists its windows (AppWindows.qml),
// which stays open while the pointer crosses over to it.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: app

    required property var group
    // The button's side; the icon takes most of it.
    property int size: 44
    // The screen edge the dock sits on: the list opens away from it.
    property int edge: Edges.Bottom
    // The icon grows under the pointer, away from the edge.
    property bool magnify: false
    readonly property bool hovered: mouse.containsMouse

    // Whose list is open, dock-wide: one at a time, and once one is open the
    // next app's opens at once as the pointer moves along.
    property Item listOwner: null
    signal listWanted(Item who)

    readonly property bool listShown: listOwner === app
    readonly property bool pointerIn: hovered || (list.item?.hovered ?? false)

    onPointerInChanged: {
        if (pointerIn) {
            closing.stop();
            if (listOwner !== null) listWanted(app);
            else opening.restart();
        } else {
            opening.stop();
            closing.restart();
        }
    }

    function hideList(): void {
        opening.stop();
        if (listShown) listWanted(null);
    }

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: Theme.moduleRadius
        color: app.group?.urgent ? Qt.alpha(Theme.warning, 0.25)
             : app.hovered ? Theme.fg(Theme.hoverOpacity)
             : app.group?.active ? Theme.fg(0.05) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    // The dots run along the edge the dock sits on; the icon makes room.
    readonly property bool upright: edge === Edges.Left || edge === Edges.Right
    readonly property bool dots: Settings.dockChoice("dots")
    readonly property int shift: dots ? 2 : 0

    IconImage {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: app.edge === Edges.Bottom ? -app.shift : app.edge === Edges.Top ? app.shift : 0
        anchors.horizontalCenterOffset: app.edge === Edges.Right ? -app.shift : app.edge === Edges.Left ? app.shift : 0
        implicitSize: Math.round(app.size * 0.72)
        source: app.group?.icon ?? ""
        opacity: app.group?.minimised ? Theme.dimOpacity : 1
        scale: app.magnify && app.hovered ? 1.35 : 1
        transformOrigin: ({ [Edges.Bottom]: Item.Bottom, [Edges.Top]: Item.Top,
                            [Edges.Left]: Item.Left, [Edges.Right]: Item.Right })[app.edge]

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Grid {
        visible: app.dots
        x: app.edge === Edges.Left ? 2 : app.edge === Edges.Right ? parent.width - width - 2 : Math.round((parent.width - width) / 2)
        y: app.edge === Edges.Top ? 2 : app.edge === Edges.Bottom ? parent.height - height - 2 : Math.round((parent.height - height) / 2)
        flow: app.upright ? Grid.TopToBottom : Grid.LeftToRight
        rows: app.upright ? 3 : 1
        columns: app.upright ? 1 : 3
        spacing: 3

        Repeater {
            model: app.group?.windows.slice(0, 3) ?? []

            Rectangle {
                required property var modelData
                readonly property bool hidden: Windows.minimised(modelData)
                readonly property bool focused: Windows.focused(modelData)
                readonly property int length: focused ? 10 : 4

                width: app.upright ? 4 : length
                height: app.upright ? length : 4
                radius: 2
                color: hidden ? "transparent" : focused ? Theme.accent : Theme.fg(0.6)
                border.width: hidden ? 1 : 0
                border.color: Theme.fg(0.6)

                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            app.hideList();
            if (event.button === Qt.MiddleButton) Windows.open(app.group);
            else Windows.activate(app.group);
        }
    }

    Timer {
        id: opening
        interval: 400
        onTriggered: app.listWanted(app)
    }

    Timer {
        id: closing
        interval: 300
        onTriggered: if (app.listShown) app.listWanted(null)
    }

    Loader {
        id: list

        active: app.listShown && app.group !== null
        sourceComponent: AppWindows {
            target: app
            group: app.group
            edge: app.edge
            onPicked: app.hideList()
        }
    }
}
