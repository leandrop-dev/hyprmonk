// A card in the middle of the focused screen, over everything, that takes the
// keyboard while open: quick actions and the power menu are one of these.
// It unfolds down from its top edge, and a click anywhere else dismisses it.
//
// The window is `windowHeight` tall with the card at its top, so a card that
// changes height grows and shrinks from a fixed top; by default it fits the
// card, which cuts a card that shrinks while it animates: one that changes
// height sets it to its tallest.
//
// `folded` comes once the card has folded away after closing: the time to
// put a card back as it opens, unseen.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

PanelWindow {
    id: overlay

    property bool open: false
    property string name: "hyprmonk-overlay"  // the layer namespace
    property int cardWidth: 420
    property real cardHeight: 0
    property int windowHeight: cardHeight + margin * 2
    default property alias content: card.data

    readonly property int margin: 32  // room around the card as it unfolds

    signal dismissed()
    signal folded()

    onVisibleChanged: if (!visible) folded()

    // Picked when it opens; it stays there while open.
    onOpenChanged: if (open) screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    visible: open || card.opacity > 0
    color: "transparent"
    implicitWidth: cardWidth + margin * 2
    implicitHeight: windowHeight
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: card }

    WlrLayershell.namespace: name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [overlay]
        active: overlay.open
        onCleared: overlay.dismissed()
    }

    Rectangle {
        id: card

        x: overlay.margin
        y: overlay.margin
        width: overlay.cardWidth
        height: overlay.cardHeight
        radius: Theme.panelRadius
        color: Theme.card
        border.width: 1
        border.color: Theme.rim
        clip: true

        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        opacity: overlay.open ? 1 : 0
        transform: Rotation {
            origin.x: card.width / 2
            origin.y: 0
            axis { x: 1; y: 0; z: 0 }
            angle: overlay.open ? 0 : -90

            Behavior on angle {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
