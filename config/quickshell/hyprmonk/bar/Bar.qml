// The bar on one screen: three floating cards (left, centre, right) on a
// transparent strip. Only the cards are drawn, so Hyprland's blur (rules.lua,
// namespace hyprmonk-bar) applies to them alone.
//
// A card grows down into a panel (Panels.open), so the window always has room
// below the cards: resizing it as a panel opens would make the animation jump.
// Windows still keep only the bar's own height clear, and clicks reach the
// cards alone (the mask); the rest of the window lets them through.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.panels
import qs.services

PanelWindow {
    id: bar

    readonly property int baseHeight: Theme.barHeight + Theme.barGap * 2
    readonly property bool panelOpen: Panels.open !== "" && Panels.screen === screen?.name

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: baseHeight + Math.round((screen?.height ?? 1080) * 0.75)
    exclusiveZone: baseHeight
    color: "transparent"
    mask: Region {
        Region { item: leftCard }
        Region { item: centreCard }
        Region { item: rightCard }
    }

    WlrLayershell.namespace: "hyprmonk-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // A click anywhere else closes the panel; so does Escape.
    HyprlandFocusGrab {
        windows: [bar]
        active: bar.panelOpen
        onCleared: Panels.close()
    }

    Item {
        focus: bar.panelOpen
        Keys.onEscapePressed: Panels.close()
    }

    Card {
        id: leftCard

        side: Qt.AlignLeft
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barGap

        Launcher {}
        Workspaces { screen: bar.screen }
        Overview {}
        Temperature {}
    }

    Card {
        id: centreCard

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barGap
        panel: mediaOpen ? mediaPanel : null
        panelWidth: 490

        // The spectrum stays; the media slides out beside it while hovered
        // (folding a moment after the pointer leaves) or while its panel is
        // open.
        readonly property bool mediaOpen: bar.panelOpen && Panels.open === "media"
        property bool hovered: false
        readonly property bool showMedia: Player.current !== null && (hovered || mediaOpen)

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    fold.stop();
                    centreCard.hovered = true;
                } else {
                    fold.restart();
                }
            }
        }

        Timer {
            id: fold
            interval: 400
            onTriggered: centreCard.hovered = false
        }

        Spectrum { active: centreCard.mediaOpen }

        Item {
            id: drawer

            property real reveal: centreCard.showMedia ? 1 : 0

            visible: reveal > 0
            clip: true
            implicitWidth: media.implicitWidth * reveal
            implicitHeight: media.implicitHeight

            Behavior on reveal {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Media {
                id: media
                active: centreCard.mediaOpen
            }
        }
    }

    Card {
        id: rightCard

        side: Qt.AlignRight
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barGap
        panel: !bar.panelOpen ? null
             : Panels.open === "sound" ? outputPanel
             : Panels.open === "microphone" ? inputPanel
             : Panels.open === "batteries" ? batteryPanel
             : Panels.open === "calendar" ? calendarPanel
             : null

        Batteries { active: bar.panelOpen && Panels.open === "batteries" }
        Volume { active: bar.panelOpen && Panels.open === "sound" }
        Microphone { active: bar.panelOpen && Panels.open === "microphone" }
        NotificationBell {}
        Clock { active: bar.panelOpen && Panels.open === "calendar" }
        QuickActionsButton {}
        PowerButton {}
    }

    Component {
        id: outputPanel
        SoundPanel { kind: "output" }
    }

    Component {
        id: inputPanel
        SoundPanel { kind: "input" }
    }

    Component {
        id: batteryPanel
        BatteryPanel {}
    }

    Component {
        id: calendarPanel
        CalendarPanel {}
    }

    Component {
        id: mediaPanel
        MediaPanel {}
    }
}
