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

    // The strip the centre card has between the others. It stays centred while
    // it fits there, moves aside when it does not (the drawer open on a small
    // screen), and the media gives up its text, then itself, before overlapping.
    readonly property int cardGap: 8
    readonly property real freeLeft: Theme.barMargin + leftCard.baseWidth + cardGap
    readonly property real freeRight: width - Theme.barMargin - rightCard.baseWidth - cardGap
    readonly property real freeWidth: freeRight - freeLeft

    // A panel opens under the card holding its module; the right card takes
    // those of hidden modules (over IPC). The media's has the centre card.
    readonly property var panels: ({
        sound: outputPanel,
        microphone: inputPanel,
        network: networkPanel,
        bluetooth: bluetoothPanel,
        batteries: batteryPanel,
        calendar: calendarPanel,
        tray: trayMenu
    })
    readonly property Component openPanel: panelOpen ? panels[Panels.open] ?? null : null
    // Not with none open: modules without a panel would match "".
    readonly property bool panelOnLeft: Panels.open !== "" && Settings.bar.left.some(key => Settings.barPanel(key) === Panels.open)

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

    // Stay awake (services/Awake.qml): each bar holds the inhibitor, so it
    // lasts while any screen has its bar.
    IdleInhibitor {
        window: bar
        enabled: Awake.on
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
        visible: Settings.bar.left.length > 0
        panel: bar.panelOnLeft ? bar.openPanel : null

        // Up to the right card: on a small screen the hardware drawer's far
        // end stays folded away.
        BarModules {
            model: Settings.bar.left
            screen: bar.screen
            panelOpen: bar.panelOpen
            room: bar.freeRight - Theme.barMargin - Theme.cardPadding * 2
        }
    }

    Card {
        id: centreCard

        x: Math.round(Math.max(bar.freeLeft, Math.min((bar.width - width) / 2, bar.freeRight - width)))
        anchors.top: parent.top
        anchors.topMargin: Theme.barGap
        panel: mediaOpen ? mediaPanel : null
        panelWidth: 490
        visible: bar.freeWidth >= spectrum.implicitWidth + Theme.cardPadding * 2

        // The spectrum stays; the media slides out beside it while hovered
        // (folding a moment after the pointer leaves), while its panel is
        // open, or while it sings lyrics "In bar".
        readonly property bool mediaOpen: bar.panelOpen && Panels.open === "media"
        property bool pointerNear: false
        readonly property bool singing: Lyrics.inBar && Lyrics.line !== "" && (Player.current?.isPlaying ?? false)
        readonly property bool showMedia: Player.current !== null && media.fits && (pointerNear || mediaOpen || singing)

        onHoveredChanged: {
            if (hovered) {
                fold.stop();
                pointerNear = true;
            } else {
                fold.restart();
            }
        }

        Timer {
            id: fold
            interval: 400
            onTriggered: centreCard.pointerNear = false
        }

        Spectrum {
            id: spectrum
            active: centreCard.mediaOpen
        }

        Item {
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
                room: bar.freeWidth - spectrum.implicitWidth - Theme.cardPadding * 2 - 2
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
        visible: Settings.bar.right.length > 0 || panel !== null
        panel: bar.panelOnLeft ? null : bar.openPanel

        BarModules {
            model: Settings.bar.right
            screen: bar.screen
            panelOpen: bar.panelOpen
            room: bar.width - Theme.barMargin - bar.freeLeft - Theme.cardPadding * 2
        }
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
        id: networkPanel
        NetworkPanel {}
    }

    Component {
        id: bluetoothPanel
        BluetoothPanel {}
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
        id: trayMenu
        TrayMenu {}
    }

    Component {
        id: mediaPanel
        MediaPanel {}
    }
}
