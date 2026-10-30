// Recording the focused screen or a region picked for each recording
// (`hyprmonk record`, which becomes GPU Screen Recorder), with the system's
// sound and the microphone as set here, kept between sessions; a change counts
// from the next recording. SIGINT ends it and saves the file; the bar shows
// the time while it runs, and a notification offers the file after. It is
// `active` from the first line it prints, so not while a region is being
// picked; Escape there ends it with nothing printed.
//
// IPC: qs -c hyprmonk ipc call recorder toggle
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property bool active: recording.running && file !== ""
    readonly property var areas: ["Screen", "Region"]
    readonly property string area: settings.area
    readonly property bool sound: settings.sound
    readonly property bool microphone: settings.microphone

    function setArea(name: string): void { settings.area = name; }
    function setSound(on: bool): void { settings.sound = on; }
    function setMicrophone(on: bool): void { settings.microphone = on; }

    property int seconds: 0

    // "0:07", "1:02:45"
    readonly property string elapsed: {
        const pad = n => String(n).padStart(2, "0");
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds / 60) % 60;
        return (hours > 0 ? hours + ":" + pad(minutes) : minutes) + ":" + pad(seconds % 60);
    }

    readonly property string hyprmonk: Quickshell.env("HOME") + "/.local/bin/hyprmonk"
    property string file: ""
    property string failure: ""
    property real startedAt: 0

    function toggle(): void {
        if (recording.running) {
            if (active) recording.signal(2);  // SIGINT
            return;
        }
        const target = area === "Region" ? "region" : Hyprland.focusedMonitor?.name;
        if (!target) return;
        file = "";
        failure = "";
        recording.command = [hyprmonk, "record", target,
                             ...(sound ? ["--sound"] : []),
                             ...(microphone ? ["--microphone"] : [])];
        recording.running = true;
    }

    Process {
        id: recording

        // Its first line is the file; the recorder's own come after.
        stdout: SplitParser {
            onRead: line => {
                if (root.file !== "") return;
                root.seconds = 0;
                root.startedAt = Date.now();
                root.file = line;
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("error")) root.failure = line;
            }
        }
        onExited: (code, status) => {
            const saved = root.file;
            root.file = "";
            if (code === 0 && saved !== "") {
                Quickshell.execDetached([root.hyprmonk, "recording-saved", saved]);
            } else if (code !== 0) {
                Quickshell.execDetached(["notify-send", "--app-name", "Screen recording", "--icon", "dialog-error",
                                         "Recording failed", root.failure || "It stopped with code " + code]);
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.seconds = Math.round((Date.now() - root.startedAt) / 1000)
    }

    FileView {
        path: Theme.stateDir + "/recorder.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings

            property string area: "Screen"
            property bool sound: true
            property bool microphone: false
        }
    }

    IpcHandler {
        target: "recorder"

        function toggle(): void {
            root.toggle();
        }
    }
}
