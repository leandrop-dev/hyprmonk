// The main keyboard's layouts as Hyprland has them: their codes ("us", "pt"),
// the one in use and its name ("Portuguese"). Read at start, and again when
// the layout switches or the config reloads.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property var layouts: []
    property int index: 0
    property string name: ""
    // The first layout listed is the default one.
    readonly property bool isDefault: index === 0

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"]);
    }

    Process {
        id: reader
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboard = JSON.parse(text).keyboards.find(k => k.main);
                root.layouts = keyboard?.layout ? keyboard.layout.split(",") : [];
                root.index = keyboard?.active_layout_index ?? 0;
                root.name = keyboard?.active_keymap ?? "";
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout" || event.name === "configreloaded") reader.running = true;
        }
    }
}
