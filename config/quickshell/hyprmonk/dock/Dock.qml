// The dock on one screen: the open apps (services/Windows.qml) on a card
// like the bar's, centred on the edge picked in Settings > Dock (bottom to
// begin with). On the left or right it stands upright. Hidden while no app
// is open, and when turned off. Blurred by Hyprland like every hyprmonk-*
// layer (rules.lua).
//
// The window spans the whole edge, but only the card takes the pointer (the
// mask), so the rest lets clicks through. Hiding:
// - never: windows keep clear of it;
// - always: the card slides off the edge, and back while the pointer is at
//   the edge, on the card or in a window list;
// - while a window touches it: the same, and also shown while no window of
//   the workspace on its screen overlaps it. Floating windows move and
//   resize without Hyprland saying so, so their places are read twice a
//   second while this is picked.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: dock

    readonly property string position: Settings.dockChoice("position")
    readonly property int edge: ({ bottom: Edges.Bottom, top: Edges.Top, left: Edges.Left, right: Edges.Right })[position]
    readonly property bool upright: position === "left" || position === "right"
    readonly property int size: Settings.dockSize
    readonly property string autohide: Settings.dockChoice("autohide")
    readonly property bool magnify: Settings.dockChoice("magnify")
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int workspace: monitor?.activeWorkspace?.id ?? -1
    readonly property var groups: Windows.groups(Settings.dockChoice("scope"), workspace)
    // The app whose window list is open (DockApp.qml).
    property Item listOwner: null

    // Across the edge: the card and its gap, plus room for a grown icon.
    readonly property int cardDepth: (upright ? card.implicitWidth : card.implicitHeight)
    readonly property int depth: cardDepth + Theme.barGap * 2 + (magnify ? Math.round(size * 0.2) : 0)

    // Shown: never hiding, held by the pointer, or (touch) left untouched.
    property bool held: false
    readonly property bool pointerIn: cardHover.hovered || edgeHover.hovered || listOwner !== null
    readonly property bool revealed: autohide === "off" || held || (autohide === "touch" && !touched)

    onPointerInChanged: {
        if (pointerIn) {
            letGo.stop();
            held = true;
        } else {
            letGo.restart();
        }
    }

    Timer {
        id: letGo
        interval: 500
        onTriggered: dock.held = false
    }

    // The card's place on screen while shown, in Hyprland's coordinates:
    // centred in what other layers (the bar) leave of the screen.
    readonly property var reserved: monitor?.lastIpcObject?.reserved ?? [0, 0, 0, 0]
    readonly property rect shownRect: {
        const w = card.implicitWidth, h = card.implicitHeight, g = Theme.barGap;
        const ax = (screen?.x ?? 0) + reserved[0], ay = (screen?.y ?? 0) + reserved[1];
        const aw = (screen?.width ?? 0) - reserved[0] - reserved[2];
        const ah = (screen?.height ?? 0) - reserved[1] - reserved[3];
        if (position === "bottom") return Qt.rect(ax + (aw - w) / 2, ay + ah - g - h, w, h);
        if (position === "top") return Qt.rect(ax + (aw - w) / 2, ay + g, w, h);
        if (position === "left") return Qt.rect(ax + g, ay + (ah - h) / 2, w, h);
        return Qt.rect(ax + aw - g - w, ay + (ah - h) / 2, w, h);
    }

    readonly property bool touched: autohide === "touch" && Hyprland.toplevels.values.some(window => {
        const info = window.lastIpcObject;
        if (window.workspace?.id !== workspace || !info?.at || !info?.size) return false;
        const r = shownRect;
        return info.at[0] < r.x + r.width && info.at[0] + info.size[0] > r.x
            && info.at[1] < r.y + r.height && info.at[1] + info.size[1] > r.y;
    })

    Timer {
        interval: 500
        repeat: true
        running: dock.visible && dock.autohide === "touch"
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }

    visible: Settings.dockChoice("shown") && groups.length > 0
    anchors {
        bottom: position !== "top"
        top: position !== "bottom"
        left: position !== "right"
        right: position !== "left"
    }
    implicitWidth: upright ? depth : 0
    implicitHeight: upright ? 0 : depth
    exclusiveZone: autohide === "off" ? cardDepth + Theme.barGap * 2 : 0
    color: "transparent"
    mask: Region {
        item: dock.revealed ? card : edgeStrip
    }

    WlrLayershell.namespace: "hyprmonk-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Where the pointer reveals a hidden dock: the screen's last pixels.
    Item {
        id: edgeStrip

        x: dock.position === "right" ? parent.width - width : 0
        y: dock.position === "bottom" ? parent.height - height : 0
        width: dock.upright ? 2 : parent.width
        height: dock.upright ? parent.height : 2

        HoverHandler {
            id: edgeHover
        }
    }

    Rectangle {
        id: card

        // 1 shown, 0 slid off the edge.
        property real openness: dock.revealed ? 1 : 0
        readonly property real away: (1 - openness) * (dock.cardDepth + Theme.barGap * 2)

        Behavior on openness {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // A gap from the screen's edge, as the bar's cards have.
        x: dock.position === "left" ? Theme.barGap - away
         : dock.position === "right" ? parent.width - width - Theme.barGap + away
         : Math.round((parent.width - width) / 2)
        y: dock.position === "top" ? Theme.barGap - away
         : dock.position === "bottom" ? parent.height - height - Theme.barGap + away
         : Math.round((parent.height - height) / 2)
        implicitWidth: apps.implicitWidth + Theme.cardPadding * 2
        implicitHeight: apps.implicitHeight + Theme.cardPadding * 2
        radius: Theme.cardRadius
        color: Theme.card
        border.width: 1
        border.color: Theme.rim

        HoverHandler {
            id: cardHover
        }

        GridLayout {
            id: apps

            anchors.centerIn: parent
            flow: dock.upright ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: dock.upright ? -1 : 1
            columns: dock.upright ? 1 : -1
            rowSpacing: 2
            columnSpacing: 2

            // Keys only, so an app's button stays (hover and all) while its
            // windows change.
            Repeater {
                model: ScriptModel {
                    values: dock.groups.map(group => group.key)
                }

                DockApp {
                    required property string modelData
                    group: dock.groups.find(g => g.key === modelData) ?? null
                    size: dock.size
                    edge: dock.edge
                    magnify: dock.magnify
                    listOwner: dock.listOwner
                    onListWanted: who => dock.listOwner = who
                }
            }
        }
    }
}
