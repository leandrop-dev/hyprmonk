// The clipboard history for the launcher's Clipboard tab: what cliphist keeps
// (hyprmonk-clipboard.service stores it), newest first. copy() puts one back
// on the clipboard, remove() forgets it.
//
// A list line is only a preview, so an image's `preview` is decoded to a file
// once one is picked; `imagePath` is that file, empty until it is ready.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var clips: []
    property string imagePath: ""

    readonly property int previewChars: 600
    readonly property string imageFile: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprmonk-clipboard-image"

    function refresh(): void {
        if (!list.running) list.running = true;
    }

    // Newest first whatever is typed: recency is the order that matters here.
    function find(typed: string): var {
        const q = typed.trim().toLowerCase();
        return q === "" ? clips : clips.filter(clip => clip.text.toLowerCase().includes(q));
    }

    function copy(clip: var): void {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", clip.id]);
    }

    function remove(clip: var): void {
        clips = clips.filter(other => other.id !== clip.id);
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", clip.id]);
    }

    function preview(clip: var): void {
        imagePath = "";
        wanted = clip?.image ? clip.id : "";
        if (wanted !== "") settle.restart();
    }

    property string wanted: ""

    // "[[ binary data 1.2 MiB png 800x600 ]]" is how cliphist lists an image.
    function parse(line: string): var {
        const tab = line.indexOf("\t");
        const id = line.slice(0, tab);
        const text = line.slice(tab + 1);
        const image = /^\[\[ binary data (.+) (\w+) (\d+x\d+) \]\]$/.exec(text);
        if (image) return { kind: "clip", id, text, name: "Image " + image[3], detail: image[2] + ", " + image[1], image: true };
        return { kind: "clip", id, text, name: text, detail: "", image: false };
    }

    Process {
        id: list

        command: ["cliphist", "-preview-width", String(root.previewChars), "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clips = text.split("\n").filter(line => line.includes("\t")).map(root.parse)
        }
    }

    // Moving through a list of images decodes only the one stopped on.
    Timer {
        id: settle

        interval: 120
        onTriggered: {
            if (decode.running) restart();
            else decode.running = true;
        }
    }

    Process {
        id: decode

        command: ["sh", "-c", "cliphist decode \"$1\" > \"$2\"", "sh", root.wanted, root.imageFile]
        onExited: (code, status) => {
            if (code === 0 && root.wanted !== "") root.imagePath = "file://" + root.imageFile;
        }
    }
}
