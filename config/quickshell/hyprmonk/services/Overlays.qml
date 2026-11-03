// Which centred card is open (the launcher, quick actions, the power menu,
// the key guide, the wallpaper picker): one at a time, on the screen focused when it opened.
// Opening one closes any bar panel and the notification centre.
//
// A card opened while another is still folding away (quick actions running
// "Power menu") waits until that one is gone: when a surface that held the
// keyboard unmaps, Hyprland hands the keyboard to a window, even with
// another card asking for it, and the new card would get no keys. For the
// same reason the OSD and the notification pop-ups stay mapped (empty)
// while a card is open, instead of unmapping under it, and they stay on
// their screen (`popupScreen`) while anything holding the keyboard is open:
// following the pointer to another screen remaps them.
//
// IPC: qs -c hyprmonk ipc call overlays toggle NAME | close
//      ("launcher", "clipboard" (the launcher on that tab), "quickactions",
//      "power", "keyguide", "wallpapers" or "settings")
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string open: ""  // "" when none
    property real closedAt: 0

    // Where the OSD, the pop-ups and the notification centre go: the focused
    // screen, but held while a card, a bar panel or the centre is open.
    readonly property bool holding: open !== "" || Panels.open !== "" || Notifications.centerOpen
    readonly property ShellScreen focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0] ?? null
    property ShellScreen popupScreen: null

    function follow(): void {
        if (!holding || !Quickshell.screens.includes(popupScreen)) popupScreen = focusedScreen;
    }

    onFocusedScreenChanged: follow()
    onHoldingChanged: follow()
    Component.onCompleted: follow()

    readonly property int fold: 240  // a card's fold (widgets/Overlay.qml), and a little more

    function toggle(name: string): void {
        if (open === name) {
            close();
            return;
        }
        Panels.close();
        if (open !== "") close();
        // The centre takes the keyboard too, and unmaps once a card grabs it.
        if (Notifications.centerOpen) {
            Notifications.centerOpen = false;
            closedAt = Date.now();
        }
        const wait = closedAt + fold - Date.now();
        if (wait > 0) {
            next.name = name;
            next.interval = wait;
            next.restart();
        } else {
            open = name;
        }
    }

    function close(): void {
        if (open !== "") closedAt = Date.now();
        open = "";
        next.stop();
    }

    Timer {
        id: next

        property string name: ""

        onTriggered: root.open = name
    }

    IpcHandler {
        target: "overlays"

        function toggle(name: string): void {
            root.toggle(name);
        }

        function close(): void {
            root.close();
        }
    }
}
