// Recording the focused screen, a region picked for each recording or the
// focused window (`hyprmonk record`, which becomes GPU Screen Recorder), with
// the system's sound and the microphone as set here, kept between sessions; a
// change counts from the next recording. SIGINT ends it and saves the file;
// the bar shows the time while it runs, and a notification offers the file
// after. It is `active` from the first line it prints, so not while a region
// is being picked; Escape there ends it with nothing printed. SIGUSR2 pauses
// it, and resumes it.
//
// A window's picture freezes for good if it changes size or closes, while the
// recorder runs on, so either ends the recording there. A change of size
// shows as the recorder's stream leaving "streaming"; a close shows nothing
// from the recorder, so it comes from Hyprland.
//
// The replay keeps the last minute of the focused screen in memory, with the
// same sound, until saved; it can run beside a recording. It costs about 17%
// of a core while on, so it is switched on by hand and not kept between
// sessions. SIGUSR1 saves, SIGINT drops it. That signal kills the recorder
// until it has started, and a save with nothing to save only prints an error
// where the file would be, so the first moments of a replay cannot save.
//
// IPC: qs -c hyprmonk ipc call recorder toggle
//      qs -c hyprmonk ipc call recorder pause
//      qs -c hyprmonk ipc call recorder replay
//      qs -c hyprmonk ipc call recorder saveReplay
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property bool active: recording.running && file !== ""
    readonly property bool replaying: replay.running
    readonly property var areas: ["Screen", "Region", "Window"]
    readonly property string area: settings.area
    readonly property bool sound: settings.sound
    readonly property bool microphone: settings.microphone

    function setArea(name: string): void { settings.area = name; }
    function setSound(on: bool): void { settings.sound = on; }
    function setMicrophone(on: bool): void { settings.microphone = on; }

    property bool paused: false
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
    property string replayFailure: ""
    property real startedAt: 0
    property string window: ""  // the window's address while one is recorded

    function toggle(): void {
        if (recording.running) {
            if (active) stop();
            return;
        }
        window = area === "Window" ? Hyprland.activeToplevel?.address ?? "" : "";
        if (area === "Window" && window === "") {
            notify("No window to record", "Focus one first");
            return;
        }
        const target = window !== "" ? "window:" + window
                     : area === "Region" ? "region" : Hyprland.focusedMonitor?.name;
        if (!target) return;
        file = "";
        failure = "";
        recording.command = [hyprmonk, "record", target, ...audioFlags()];
        recording.running = true;
    }

    function stop(): void {
        window = "";
        recording.signal(2);  // SIGINT
    }

    function pause(): void {
        if (!active) return;
        recording.signal(12);  // SIGUSR2
        paused = !paused;
        if (!paused) startedAt = Date.now() - seconds * 1000;
    }

    function toggleReplay(): void {
        if (replay.running) {
            replay.signal(2);  // SIGINT
            return;
        }
        const target = Hyprland.focusedMonitor?.name;
        if (!target) return;
        replayFailure = "";
        replay.command = [hyprmonk, "replay", target, ...audioFlags()];
        replay.running = true;
        replayStarting.restart();
    }

    function saveReplay(): void {
        if (!replay.running) {
            notify("Replay is off", "Turn it on in quick actions");
        } else if (!replayStarting.running) {
            replay.signal(10);  // SIGUSR1
        }
    }

    function audioFlags(): var {
        return [...(sound ? ["--sound"] : []), ...(microphone ? ["--microphone"] : [])];
    }

    function notify(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "--app-name", "Screen recording", "--icon", "dialog-error",
                                 summary, body]);
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
                if (root.window !== "" && line.includes('previous state: "streaming"')) {
                    root.notify("Recording stopped", "The window changed size, which ends a window's recording");
                    root.stop();
                }
            }
        }
        onExited: (code, status) => {
            const saved = root.file;
            root.file = "";
            root.window = "";
            root.paused = false;
            if (code === 0 && saved !== "") {
                Quickshell.execDetached([root.hyprmonk, "recording-saved", saved]);
            } else if (code !== 0) {
                root.notify("Recording failed", root.failure || "It stopped with code " + code);
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "closewindow" && event.data === root.window) root.stop();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: root.seconds = Math.round((Date.now() - root.startedAt) / 1000)
    }

    Process {
        id: replay

        // Each save prints its file, or an error in its place.
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("/")) Quickshell.execDetached([root.hyprmonk, "recording-saved", line]);
                else root.notify("Replay not saved", line);
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("error")) root.replayFailure = line;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.notify("Replay stopped", root.replayFailure || "It stopped with code " + code);
        }
    }

    Timer {
        id: replayStarting
        interval: 2000
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

        function pause(): void {
            root.pause();
        }

        function replay(): void {
            root.toggleReplay();
        }

        function saveReplay(): void {
            root.saveReplay();
        }
    }
}
