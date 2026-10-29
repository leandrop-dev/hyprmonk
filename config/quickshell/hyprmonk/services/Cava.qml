// The audio spectrum for the bar: cava (services/cava.conf) reading what
// the default output plays, as ten levels from 0 to 1. Started again if it
// stops (Pipewire restarting); stopped while nobody sees the bar (the screen
// locked, game mode on). A line equal to the last one changes nothing. Also how the bar draws it (bar/Spectrum.qml):
// one of `styles`, picked in quick actions > Spectrum and kept in
// spectrum.json.
//
// IPC: qs -c hyprmonk ipc call spectrum style NAME  (wave, bars, equalizer,
//      peaks, leds, dots or mirror)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // Name -> label, in the picker's order.
    readonly property var styles: ({
        wave: "Wave",
        bars: "Bars",
        equalizer: "Equalizer",
        peaks: "Peaks",
        leds: "LEDs",
        dots: "Dots",
        mirror: "Mirror"
    })
    // A previewed style (quick actions, while moving through them) shows
    // without being saved.
    readonly property string savedStyle: settings.style in styles ? settings.style : "wave"
    property string previewStyle: ""
    readonly property string style: previewStyle in styles ? previewStyle : savedStyle

    function setStyle(name: string): void {
        if (name in styles) settings.style = name;
    }

    FileView {
        path: Theme.stateDir + "/spectrum.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string style: "wave"
        }
    }

    IpcHandler {
        target: "spectrum"

        function style(name: string): void {
            root.setStyle(name);
        }
    }

    readonly property int bands: 10
    property var levels: []
    readonly property bool silent: levels.every(level => level === 0)

    readonly property bool wanted: !Session.locked && !GameMode.on
    property bool alive: true  // false for a moment after cava stops
    property string lastLine: ""

    Process {
        id: cava
        running: root.wanted && root.alive
        command: ["cava", "-p", Quickshell.shellPath("services/cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                if (line === root.lastLine) return;
                root.lastLine = line;
                root.levels = line.split(";")
                    .filter(value => value !== "")
                    .map(value => Math.min(1, Number(value) / 100));
            }
        }
        onExited: {
            root.levels = [];
            root.lastLine = "";
            root.alive = false;
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: root.alive = true
    }
}
