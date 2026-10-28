// The wallpaper: which picture the shell draws behind every window
// (wallpaper/Wallpaper.qml), and the pictures to choose from, the images in
// one folder (~/Pictures/Wallpapers unless wallpaper.json names another).
// Setting one also runs matugen on it, so the accent follows.
//
// IPC: qs -c hyprmonk ipc call wallpaper set PATH | random | get
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

    // Taken once matugen has read it: a path that is no picture changes
    // nothing, and the colours change with the picture.
    function set(file: string): void {
        colours.from(file);
    }

    function random(): void {
        const others = files.filter(file => file !== path);
        if (others.length > 0) set(others[Math.floor(Math.random() * others.length)]);
    }

    FolderListModel {
        id: pictures

        folder: "file://" + root.folder
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
        }
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
            if (code === 0) settings.path = file;
            else console.warn("wallpaper: matugen could not read", file);
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
            root.makeFirstColours();
        }

        JsonAdapter {
            id: settings
            property string path: ""
            property string folder: ""
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.set(path);
        }

        function random(): void {
            root.random();
        }

        function get(): string {
            return root.path;
        }
    }
}
