// Recording the focused screen with its sound (`hyprmonk record`, which
// becomes GPU Screen Recorder). SIGINT ends it and saves the file; the bar
// shows the time while it runs, and a notification offers the file after.
//
// IPC: qs -c hyprmonk ipc call recorder toggle
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property bool active: recording.running
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
        if (active) {
            recording.signal(2);  // SIGINT
            return;
        }
        const monitor = Hyprland.focusedMonitor?.name;
        if (!monitor) return;
        file = "";
        failure = "";
        seconds = 0;
        startedAt = Date.now();
        recording.command = [hyprmonk, "record", monitor];
        recording.running = true;
    }

    Process {
        id: recording

        // Its first line is the file; the recorder's own come after.
        stdout: SplitParser {
            onRead: line => {
                if (root.file === "") root.file = line;
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("error")) root.failure = line;
            }
        }
        onExited: (code, status) => {
            if (code === 0 && root.file !== "") {
                Quickshell.execDetached([root.hyprmonk, "recording-saved", root.file]);
            } else {
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

    IpcHandler {
        target: "recorder"

        function toggle(): void {
            root.toggle();
        }
    }
}
