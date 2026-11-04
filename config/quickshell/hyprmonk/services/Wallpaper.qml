// The wallpaper: which picture the shell draws behind every window
// (wallpaper/Background.qml), and the pictures to choose from, the images in
// one folder (~/Pictures/Wallpapers unless wallpaper.json names another).
// Setting one also runs matugen on it, so the accent follows.
//
// How a new one comes in, `transition`, is kept there too (Settings >
// Appearance): fading in, wiping across, a circle growing from where it was
// picked, or one of those at random.
//
// IPC: qs -c hyprmonk ipc call wallpaper set PATH | random | get | transition NAME| random | get
pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string path: settings.path
    readonly property string folder: settings.folder || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property var files: []  // paths, by name

    readonly property list<string> transitions: ["fade", "wipe", "circle", "random"]
    readonly property string transition: transitions.includes(settings.transition) ? settings.transition : "fade"
    // Where the last pick was made, on the whole desktop (the picker's tile),
    // or null: a circle then grows from the middle of each screen.
    property var origin: null

    function setTransition(name: string): void {
        if (transitions.includes(name)) settings.transition = name === "fade" ? "" : name;
    }

    // A picture's small copy for the picker (`hyprmonk thumbnails`).
    function thumbnail(file: string): string {
        return (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
            + "/hyprmonk/wallpapers/" + file.split("/").pop() + ".jpg";
    }

    // Shown at once, while matugen makes its colours (up to a second for a
    // large picture), which follow when it is done. Should matugen not read
    // it (no picture), the last one it read comes back.
    property string lastGood: ""

    function set(file: string, from: var): void {
        if (file === settings.path) return;
        origin = from ?? null;
        settings.path = file;
        colours.from(file);
    }

    function random(): void {
        const others = files.filter(file => file !== path);
        if (others.length > 0) set(others[Math.floor(Math.random() * others.length)], null);
    }

    FolderListModel {
        folder: Theme.fileUrl(root.folder)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        caseSensitive: false
        showDirs: false
        sortCaseSensitive: false

        onStatusChanged: if (status === FolderListModel.Ready) list()
        onCountChanged: list()

        function list(): void {
            const files = [];
            for (let i = 0; i < count; i++) files.push(get(i, "filePath"));
            root.files = files;
            thumbnailsDue.restart();
        }
    }

    // After the folder settles; a change meanwhile waits for the run to end.
    Timer {
        id: thumbnailsDue
        interval: 1000
        onTriggered: thumbnails.running ? restart() : thumbnails.running = true
    }

    Process {
        id: thumbnails
        command: [Quickshell.env("HOME") + "/.local/bin/hyprmonk", "thumbnails", root.folder]
    }

    // matugen takes a moment; a pick made meanwhile runs after it.
    Process {
        id: colours

        property string file: ""
        property string next: ""

        function from(path: string): void {
            if (running) {
                next = path;
                return;
            }
            file = path;
            command = ["matugen", "image", path, "--source-color-index", "0", "--quiet"];
            running = true;
        }

        onExited: code => {
            if (code === 0) {
                root.lastGood = file;
            } else {
                console.warn("wallpaper: matugen could not read", file);
                if (settings.path === file && next === "") settings.path = root.lastGood;
            }
            if (next === "") return;
            const queued = next;
            next = "";
            from(queued);
        }
    }

    // A wallpaper set but no colours made from it yet (the installer picks
    // one; matugen first runs here): make them, once both files are read.
    property bool settingsRead: false
    property bool coloursMissing: false

    function makeFirstColours(): void {
        if (!settingsRead || !coloursMissing || settings.path === "") return;
        coloursMissing = false;
        colours.from(settings.path);
    }

    FileView {
        path: Theme.stateDir + "/theme/colors.json"
        printErrors: false
        onLoadFailed: {
            root.coloursMissing = true;
            root.makeFirstColours();
        }
    }

    FileView {
        path: Theme.stateDir + "/wallpaper.json"
        printErrors: false
        watchChanges: true  // edited by hand: folder
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.settingsRead = true;
            if (root.lastGood === "") root.lastGood = settings.path;
            root.makeFirstColours();
        }

        JsonAdapter {
            id: settings
            property string path: ""
            property string folder: ""
            property string transition: ""
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.set(path, null);
        }

        function random(): void {
            root.random();
        }

        function get(): string {
            return root.path;
        }

        function transition(name: string): void {
            root.setTransition(name);
        }
    }
}
