// The audio spectrum for the bar: cava (services/cava.conf) reading what
// the default output plays, as ten levels from 0 to 1. Started again if it
// stops (Pipewire restarting).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bands: 10
    property var levels: []
    readonly property bool silent: levels.every(level => level === 0)

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Quickshell.shellPath("services/cava.conf")]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";")
                .filter(value => value !== "")
                .map(value => Math.min(1, Number(value) / 100))
        }
        onExited: {
            root.levels = [];
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: cava.running = true
    }
}
