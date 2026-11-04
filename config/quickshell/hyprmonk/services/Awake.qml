// Stay awake: while on, the screen neither locks nor goes off by itself.
// Each bar holds an idle inhibitor (bar/Bar.qml), which Hyprland honours for
// as long as the bar is mapped, fullscreen windows included, so hypridle's
// lock and screens-off timers never fire. A suspend picked by hand still
// goes ahead, and still locks first.
// Not kept: a restart or a new login starts with it off, so a forgotten
// switch cannot leave the machine unlocked for good, and the inhibitor dies
// with the shell.
//
// IPC: qs -c hyprmonk ipc call awake toggle  (prints the new state)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool on: false

    function toggle(): void {
        on = !on;
    }

    IpcHandler {
        target: "awake"

        function toggle(): bool {
            root.toggle();
            return root.on;
        }
    }
}
