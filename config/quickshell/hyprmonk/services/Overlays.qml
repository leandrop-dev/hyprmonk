// Which centred card is open (quick actions, the power menu): one at a time,
// on the screen focused when it opened. Opening one closes any bar panel.
//
// IPC: qs -c hyprmonk ipc call overlays toggle NAME | close
//      ("quickactions" or "power")
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string open: ""  // "" when none

    function toggle(name: string): void {
        if (open === name) {
            close();
            return;
        }
        Panels.close();
        open = name;
    }

    function close(): void {
        open = "";
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
