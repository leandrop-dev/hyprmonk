// Which bar panel is open: one at a time, under the bar of one screen (the
// focused one when it opened).
//
// IPC: qs -c hyprmonk ipc call panels toggle NAME | close
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string open: ""    // "sound", "microphone"; "" when none
    property string screen: ""  // the screen's name

    function isOpen(name: string, screenName: string): bool {
        return open === name && screen === screenName;
    }

    function toggle(name: string): void {
        const here = Hyprland.focusedMonitor?.name ?? "";
        if (isOpen(name, here)) {
            close();
            return;
        }
        screen = here;
        open = name;
    }

    function close(): void {
        open = "";
    }

    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            root.toggle(name);
        }

        function close(): void {
            root.close();
        }    }
}
